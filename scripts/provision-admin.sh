#!/usr/bin/env bash
# ============================================================
# OV Admin Provisioning — Cloudflare Access automation
#
# 1. Activate Zero Trust (one-time, idempotent)
# 2. Create Access Application for a client site (/admin/*)
# 3. Create Policy allowing specific emails
#
# Prerequisites:
#   - Cloudflare API token (edit): Access: Organizations, Apps and Policies
#   - Export: CF_API_TOKEN, CF_ACCOUNT_ID
#
# Usage:
#   ./provision-admin.sh --domain client.com --emails "team@ov.com,client@client.com" [--name "CMS Admin - Client"]
#
# One-time email verification: after first activation, Cloudflare emails the
# account owner a verification link — click it once, then everything is API-driven.
# ============================================================
set -euo pipefail

CF_API_BASE="https://api.cloudflare.com/client/v4"
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ACCOUNT_ID="${CF_ACCOUNT_ID:-}"

# --- Args ---------------------------------------------------
DOMAIN=""
EMAILS=""
APP_NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)  DOMAIN="$2";  shift 2 ;;
    --emails)  EMAILS="$2";  shift 2 ;;
    --name)    APP_NAME="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$CF_API_TOKEN" || -z "$CF_ACCOUNT_ID" ]]; then
  echo "ERROR: Set CF_API_TOKEN and CF_ACCOUNT_ID (export them or .env)" >&2
  exit 1
fi
if [[ -z "$DOMAIN" ]]; then
  echo "ERROR: --domain required" >&2
  exit 1
fi

AUTH_DOMAIN="${AUTH_DOMAIN:-ov-websites.cloudflareaccess.com}"
[[ -z "$APP_NAME" ]] && APP_NAME="CMS Admin - ${DOMAIN}"

api() { # api METHOD path data
  local method="$1" path="$2" data="${3:-}"
  local args=(-sS -X "$method" "https://api.cloudflare.com/client/v4$path"
              -H "Authorization: Bearer $CF_API_TOKEN"
              -H "Content-Type: application/json")
  if [[ -n "$data" ]]; then
    curl "${args[@]}" -d "$data"
  else
    curl "${args[@]}"
  fi
}

jq_check() { # jq_check <json>  → exits 1 if response.success != true
  local ok
  ok="$(echo "$1" | jq -r '.success // false' 2>/dev/null || echo false)"
  if [[ "$ok" != "true" ]]; then
    echo "ERROR: API call failed:" >&2
    echo "$1" | jq -r '.errors // .' >&2 2>/dev/null || echo "$1" >&2
    return 1
  fi
}

# --- 1. Activate Zero Trust (idempotent) --------------------
echo "==> 1. Checking Zero Trust organization..."
ORG_JSON="$(api GET "/accounts/$CF_ACCOUNT_ID/access/organizations")"
if echo "$ORG_JSON" | jq -e '.result.name' >/dev/null 2>&1; then
  echo "    Zero Trust already active: $(echo "$ORG_JSON" | jq -r '.result.name')"
else
  echo "    Activating Zero Trust (auth_domain=$AUTH_DOMAIN)..."
  ACT_JSON="$(api PUT "/accounts/$CF_ACCOUNT_ID/access/organizations" \
    "{\"name\":\"Overseas Visual\",\"auth_domain\":\"$AUTH_DOMAIN\",\"is_ui_read_only\":false}")"
  jq_check "$ACT_JSON"
  echo "    ✅ Activated. Check inbox for Cloudflare verification email (one-time click)."
fi

# --- 2. Resolve zone ----------------------------------------
echo "==> 2. Resolving zone for $DOMAIN..."
ZONE_JSON="$(api GET "/zones?name=$DOMAIN")"
jq_check "$ZONE_JSON"
ZONE_ID="$(echo "$ZONE_JSON" | jq -r '.result[0].id // empty')"
if [[ -z "$ZONE_ID" ]]; then
  echo "    WARN: zone '$DOMAIN' not in this Cloudflare account — will use zone_name only." >&2
fi

# --- 3. Create Access Application ----------------------------
echo "==> 3. Creating Access application '$APP_NAME'..."
APP_DATA="$(jq -n \
  --arg name "$APP_NAME" \
  --arg domain "$DOMAIN" \
  --arg zoneId "${ZONE_ID:-}" \
  '{name:$name, domain:[{domain:$domain, zone_id:$zoneId}], session_duration:"8h"}')"
APP_JSON="$(api POST "/accounts/$CF_ACCOUNT_ID/access/apps" "$APP_DATA")"
jq_check "$APP_JSON"
APP_ID="$(echo "$APP_JSON" | jq -r '.result.id')"
echo "    ✅ App created: $APP_ID"

# --- 4. Create Policy (allow emails) -------------------------
echo "==> 4. Creating policy (allow emails)..."
# Build include array: [{email:"a@x"}, {email:"b@x"}]
INCLUDE_JSON="$(printf '%s' "$EMAILS" \
  | tr ',' '\n' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$' \
  | jq -R . \
  | jq -s '[.[] | {email:.}]')"
POLICY_DATA="$(jq -n \
  --arg name "OV Team + Client" \
  --argjson include "$INCLUDE_JSON" \
  '{name:$name, decision:"allow", include:$include}')"

POLICY_JSON="$(api POST "/accounts/$CF_ACCOUNT_ID/access/apps/$APP_ID/policies" "$POLICY_DATA")"
jq_check "$POLICY_JSON"
echo "    ✅ Policy created. Emails allowed: $EMAILS"

echo ""
echo "Done. Test: https://$DOMAIN/admin/ (expect login prompt, then Decap CMS)"
