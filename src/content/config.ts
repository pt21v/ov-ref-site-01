import { defineCollection, z } from 'astro:content';

// Client site content collections — fill these per client project
const siteConfig = defineCollection({
  type: 'data',
  schema: z.object({
    // Branding
    firmName: z.string(),
    tagline: z.string().optional(),
    brandColor: z.string().default('#1150AB'),
    // Contact
    email: z.string().optional(),
    whatsapp: z.string().optional(),
    instagram: z.string().optional(),
    phone: z.string().optional(),
    address: z.string().optional(),
    // SEO
    seoTitle: z.string().optional(),
    seoDescription: z.string().optional(),
  }),
});

const pages = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    navTitle: z.string().optional(),
    order: z.number().default(99),
    draft: z.boolean().default(false),
  }),
});

const projects = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    year: z.number().optional(),
    location: z.string().optional(),
    category: z.string().optional(), // residential, commercial, interior, etc.
    featured: z.boolean().default(false),
    coverImage: z.string().optional(),
    images: z.array(z.string()).default([]),
  }),
});

const services = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    order: z.number().default(99),
    icon: z.string().optional(),
  }),
});

export const collections = { siteConfig, pages, projects, services };
