# OV Client Starter — Architecture Firm Website Template

Reusable Astro starter for building client websites (Overseas Visual Website Service).

**Stack:** Astro (static) + Decap CMS + Cloudflare Pages. Zero JS, ~30KB output, $0 hosting.

---

## Start a new client project

```bash
cp -r ov-client-starter ../client-<name>   # or clone this repo
cd ../client-<name>
rm -rf node_modules .git
npm install
```

Then edit `src/content/siteConfig/site.json`:
```json
{
  "firmName": "Client Firm Name",
  "tagline": "Their tagline",
  "brandColor": "#1150AB",
  "email": "client@email.com",
  ...
}
```

## Content structure

| Collection | Path | Purpose |
|------------|------|---------|
| `siteConfig/site.json` | Branding, contact, SEO | One file per client |
| `pages/*.md` | Home, About, Services, Contact | Editable pages |
| `projects/*.md` | Portfolio entries | Each project = one file |
| `uploads/` | Media | Public folder for images |

## Pages (auto-generated)

- `/` — Home (hero + featured projects)
- `/projects/` — Portfolio grid
- `/projects/[slug]/` — Project detail + gallery
- `/[slug]/` — About, Services, Contact, etc. (from `pages/*.md`)

## Commands

```bash
npm run dev      # local dev → http://localhost:4321
npm run build    # static build → dist/
npm run preview  # preview build
```

## Deploy (Cloudflare Pages)

1. Push to GitHub (new repo per client)
2. Cloudflare → Workers & Pages → Create → Pages → Connect to Git
3. **Build command:** `npm run build`
4. **Output directory:** `dist`
5. Deploy. Free tier: unlimited bandwidth, 500 builds/mo
6. Add custom domain + SSL (Cloudflare Registrar at-cost)

## CMS (client self-editing)

- Admin at `/admin` (Decap CMS)
- Client edits pages, projects, site settings in a web UI
- Every save = git commit → auto-deploy
- Auth: requires Git Gateway (e.g. Netlify Identity) or GitHub OAuth via Decap external OAuth. If not configured, fall back to markdown edits + commits.

### Testing admin locally (dev only)

`public/admin/config.yml` is the **production** config (no `local_backend`).
To test the admin UI locally, temporarily add:

```yaml
# at the top of public/admin/config.yml
local_backend: true
```

then run:
```bash
npx decap-server        # terminal 1
npm run dev             # terminal 2 → http://localhost:4321/admin/index.html
```

**Remove `local_backend: true` again before committing/deploying.**

## 🔒 Protecting /admin (REQUIRED before production)

The admin UI page must NOT be publicly accessible. Use **Cloudflare Access (Zero Trust)**:

### Option A: Automated (recommended)

```bash
cp .env.example .env   # fill CF_API_TOKEN + CF_ACCOUNT_ID
source .env

# One-time: activates Zero Trust (then click the verification email once)
# Per client:
./scripts/provision-admin.sh \
  --domain client.com \
  --emails "team@ov.com,client@client.com"
```

The script creates the Access application (`/admin/*`, 8h sessions) + policy allowing the given emails.

### Option B: Manual (dashboard)

1. Cloudflare dashboard → **Zero Trust** → **Access** → **Applications**
2. **Add an application** → Self-hosted
3. Application domain: `{client-site}.pages.dev` (or custom domain), path: `admin/*`
4. Policy: **Allow** — users by email (add OV team + client emails)
5. Session duration: 1 day (or 8 hours)

**Also block the config file** — add a second rule:
- Path: `admin/config.yml` → **Deny** all (or block non-authorized)
  - Cloudflare Pages already serves `config.yml` as a static file; Access blocks it if `admin/*` is protected, but add `admin/*.yml` explicitly if needed.

### Before every deploy — checklist
- [ ] `local_backend: true` REMOVED from `public/admin/config.yml`
- [ ] Cloudflare Access policy active on `/admin/*`
- [ ] Git auth (git-gateway / GitHub OAuth) configured
- [ ] Git token scope limited to the repo only

## 🔑 API Token Security (for provision-admin.sh)

The provisioning token can add/remove admin access — protect it like a password:

1. **Minimal scope** — only 2 permissions:
   - `Access: Organizations: Edit`
   - `Access: Apps and Policies: Edit`
   - Do NOT grant zone/DNS/workers permissions
2. **IP restriction** — Cloudflare → My Profile → API Tokens → Edit token →
   Client IP Address Filtering → set to OV office/home IPs only.
   Token then only works from those IPs.
3. **Rotate every 90 days** — or immediately when someone leaves the team.
4. **Store securely** — prefer 1Password/Bitwarden or CI secrets over plain `.env`.
5. **Never commit** — `.env` is in `.gitignore`. ✅
6. **Least privilege at runtime** — run the script on a locked-down machine,
   not shared laptops.

The script itself is safe: it reads credentials from env, never logs them,
and never writes them to disk.

## 🔐 Decap CMS Auth (Layer 2 — who can SAVE content)

Cloudflare Access protects the *page*. This section protects *writing to git*.
Decap runs in the browser — never store a long-lived PAT in browser context.

### Option A: GitHub OAuth (most secure, recommended)

1. GitHub → Settings → Developer settings → **OAuth Apps** → **New OAuth App**
   - Homepage URL: `https://{client-site}.pages.dev`
   - Authorization callback URL: `https://{your-oauth-proxy}.example.com/callback`
2. Deploy a **server-side OAuth proxy** (keeps client secret out of the browser):
   - `decap-cms-github-oauth-provider` (Node server)
   - or Netlify Identity (built-in git gateway)
3. Client gets a **short-lived token** per session — no long-lived secret in browser.
4. `public/admin/config.yml`:
   ```yaml
   backend:
     name: github
     repo: your-org/client-site
     branch: main
     base_url: https://{your-oauth-proxy}.example.com
   ```

### Option B: Fine-grained PAT (simpler, acceptable for beta)

1. GitHub → Settings → Developer settings → **Personal access tokens** →
   **Fine-grained tokens** → Generate new
2. Restrictions:
   - **Repository access:** Only this client repo
   - **Permissions:** Contents: Read and write, Metadata: Read
   - **Expiration:** 90 days (or shorter)
3. Pass the token via **Git Gateway** config (e.g. Netlify Identity env var),
   NOT hardcoded in `config.yml` which ships to the browser.
4. Rotate when it expires.

### What NOT to do
- ❌ Hardcode a classic PAT in `public/admin/config.yml` — it ships to every visitor's browser
- ❌ Wide-scope PAT (all repos) — one leak = all client sites compromised
- ❌ `local_backend: true` in production (dev-only)

### Layer 3 — Repo protection
- [ ] Enable **branch protection** on `main` (require PR review if multiple editors)
- [ ] Audit commits — every save is a git commit with author
- [ ] Review `public/uploads/` for anything unexpected

## Revisions (Web Care scope)

Each revision = 1 content change (max 5 items). Design changes / new pages = separate quote.
