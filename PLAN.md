# Member Dashboard – Fast-Track Implementation Plan

> **Priority Note :** This plan fully defers to the *opinionated play-book* you provided.  Any earlier roadmap steps are folded into the streamlined sequence below.

---
## 1. High-Level Decisions  
*Source: Play-Book §1*
| Decision | Outcome |
|----------|---------|
| **Base Template** | Vercel × Supabase Next.js Starter (`create-next-app —example supabase-nextjs`) |
| **Admin Framework** | Refine v4 + Supabase DataProvider |
| **UI Library** | shadcn/ui (Radix + Tailwind v4) |
| **Optional Slices** | Refine-User-Management · Slack-Clone realtime chat |
| **Stack** | Next.js 14 / App Router · Supabase Postgres + Auth · Refine · Tailwind · Vercel |

---
## 2. Bootstrap Monorepo  
*Source: Play-Book §2*
```bash
# A. Scaffold project
npx create-next-app@latest my-dashboard \
  --example https://github.com/vercel/supabase-nextjs
cd my-dashboard

# B. Add Refine
npx @refinedev/cli add inferencer supabase routerProvider=nextjs

# C. Install shadcn/ui
npx shadcn-ui init    # use existing Tailwind cfg
```
Resulting repo structure:
```
/               # infra files, README, CI
└─ my-app/      # Next.js project (dashboard)
    ├─ src/
    ├─ supabase/
    └─ ...
```

---
## 3. Database & Security  
*Source: Play-Book §3*
1. **Tables** `members · teams · member_roles · activity_log`  
2. **RLS** Enable on all tables; policies mirror `owner/admin/member` roles.  
3. **Edge Function** `handle_new_user` → insert into `members` on signup.

---
## 4. Core Pages (Refine + shadcn)  
*Source: Play-Book §4*
| Route | Implementation Notes |
|-------|----------------------|
| `/dashboard` | Refine `<Authenticated>` wrapper; KPI cards (shadcn `<Card>`). |
| `/profile`   | `useEditableTable` (Inferencer) for member profile. |
| `/resources` | Refine `<List>` + Storage file links. |
| `/billing`   | Optional Stripe slice from Next.js SaaS Starter. |
| `/admin/users` | Import Refine-User-Management pages; apply shadcn theme. |

---
## 5. Auth Flow  
*Source: Play-Book §5*
- Supabase email-link + OAuth already wired by starter.  
- Replace stock screens with shadcn forms.  
- Feed Supabase `session` to Refine `authProvider`.

---
## 6. Deployment & Developer Experience  
*Source: Play-Book §6*
| Task | Tooling |
|------|---------|
| Link project | `vercel link` (root dir =`my-app`) |
| Env management | `vercel env add` · devs run `vercel pull` |
| GitHub Action | Lint-only (already implemented) |
| Previews | Vercel PR previews auto-enabled |
| DB migrations | `supabase db push`, store SQL in `supabase/migrations/` |
| Optional Storybook | `npx sb init` + shadcn stories |

---
## 7. Optional Feature Slices  
*Source: Play-Book §7*
1. **Realtime Chat** – copy slack-clone tables + hooks, wrap in Refine resources.  
2. **Notifications** – Edge Functions + database triggers.  
3. **Usage Analytics** – `activity_log` + Refine charts.

---
## 8. Aggressive Timeline  
*Source: Play-Book §8*  (≈ 10 focused hours)
| Day | Deliverable |
|-----|-------------|
| 0 | Project scaffold (Steps A-C) – 1 h |
| 1 | DB schema + RLS – 2 h |
| 1 | Auth UI swap to shadcn – 1 h |
| 2 | Dashboard + Profile pages – 3 h |
| 2 | Admin Users import – 1 h |
| 3 | Polish, Vercel prod deploy – 2 h |

---
## 9. Issue / PR Workflow  
- **Epics** per Phase using GitHub Projects board.  
- Issue labels `type:feature · chore · bug · docs · security`.  
- PR template → "Closes #X", checklist for tests & lint.

---
## 10. References  
- Vercel × Supabase Starter – https://vercel.com/templates/next.js/supabase  
- Refine Supabase – https://github.com/refinedev/refine/tree/main/packages/supabase  
- User-Management Example – https://github.com/supabase/supabase/tree/master/examples/user-management/refine-user-management  
- shadcn/ui – https://ui.shadcn.com  
- Next.js SaaS Starter – https://github.com/nextjs/saas-starter

---
### Next Steps
1. Spin up Supabase project and grab env vars.  
2. Run bootstrap commands (Section 2).  
3. Confirm auth round-trip works.  
4. Proceed with DB & page scaffolding per timeline.

---
## 11. Monorepo Tidy-Up Implementation
*Added based on feature-starter integrations*

When integrating multiple starter templates (Supabase Starter, SaaS-Starter, Update-Starter, Partner-Gallery), we need a scalable approach to code organization. A monorepo structure is recommended for the following reasons:

- Clean separation of apps vs. shared code
- Ability to cherry-pick features from each starter without duplicating code
- Easy integration of Stripe billing, search functionality, and other components
- Future-proofing for adding marketing sites or additional apps

### Monorepo Setup Steps

| Step | What to do | Why it helps |
|------|-------------|--------------|
| **1. Promote root to a workspace manager** | • Move the current `my-app/` to `apps/dashboard/`<br>• Create root `package.json` with `"workspaces": ["apps/*","packages/*"]` | Clean separation of apps vs shared code; tooling sees only one lock-file |
| **2. Initialize Turborepo** | `npx turbo init` → creates `turbo.json` | Remote caching on Vercel; parallel builds; one‐line CI |
| **3. Extract shared bits** | `packages/ui` (shadcn components)<br>`packages/db` (Supabase client & Zod schemas)<br>`packages/config` (ESLint / Tailwind / tsconfig bases) | Each starter slice can import these instead of duplicating code |
| **4. Vendor feature slices** | • Copy SaaS-Starter's Stripe billing logic into `packages/billing`<br>• Copy Partner-Gallery's media/search helpers into `packages/gallery` | Keeps third-party code isolated; easy to update or eject |
| **5. Remove duplicate root files** | Delete root `postcss.config.mjs`, `next.config.ts`, etc. (they now live in packages or apps) | Eliminates confusion; root only orchestrates |
| **6. Update scripts & CI** | Root `package.json`:<br>`"dev":"turbo run dev --parallel"`<br>`"build":"turbo run build"`<br>GitHub Action runs `turbo run lint` | One command for all packages; fail-fast on lint/tests |
| **7. Configure Vercel** | a) Dashboard → add **Production Directory** `apps/dashboard`<br>b) Root `vercel.json` (valid) ```json
{ 
  "version": 2, 
  "projects": [
    {
      "src": "apps/dashboard/next.config.*",
      "use": "@vercel/next"
    }
  ] 
}``` | Vercel builds only the dashboard app but honours monorepo cache |
| **8. Env-vars & secrets** | `vercel env add` per scope; devs run `vercel pull`<br>Remove any stray `.env.local` files | Single source of truth; no secrets in Git |

### How Each Template Integrates

1. **Supabase Starter**
   - Already forms the base of `apps/dashboard`
   - Authentication, DB connection, and middleware remain here

2. **SaaS-Starter (Stripe)**
   - Extract `lib/stripe.ts`, webhook route, and billing UI into `packages/billing/`
   - Import into dashboard where needed
   - Utilize Stripe Customer Portal for subscription management

3. **Update-Starter**
   - Cherry-pick lint rules and CI scripts into `packages/config/`
   - Follow patterns for incremental Next.js upgrades

4. **Supabase Partner-Gallery**
   - Extract Postgres full-text search helpers to `packages/gallery/`
   - Copy Storage utilities and media handling components
   - Expose via hooks to dashboard pages

### Net Results
- No duplicated configs; each concern lives once in dedicated packages
- Adding future apps (e.g., marketing site) requires minimal changes
- Vercel caches builds across the monorepo
- Simplified developer onboarding: one install, one dev command 