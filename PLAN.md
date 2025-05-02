# Member Dashboard – Fast-Track Implementation Plan

> **Priority Note :** This plan fully defers to the *opinionated play-book* you provided.  Any earlier roadmap steps are folded into the streamlined sequence below.

---
## 🚀 Implementation Status Overview

| Component | Status | Notes |
|-----------|--------|-------|
| **Monorepo Structure** | ✅ COMPLETED | Full workspace setup with apps/packages |
| **DevOps & CI/CD** | ✅ COMPLETED | Vercel, GitHub Actions, env management |
| **Database & Auth** | ❌ PENDING | Tables, RLS and user flows |
| **Core UI Pages** | ❌ PENDING | Dashboard, profile and admin screens |
| **Component Library** | 🚧 IN PROGRESS | Package structure ready, implementations needed |
| **Feature Slices** | 🚧 IN PROGRESS | Skeleton structure for billing/gallery |

---
## 1. High-Level Decisions ✅  
*Source: Play-Book §1*
| Decision | Outcome |
|----------|---------|
| **Base Template** | Vercel × Supabase Next.js Starter (`create-next-app —example supabase-nextjs`) |
| **Admin Framework** | Refine v4 + Supabase DataProvider |
| **UI Library** | shadcn/ui (Radix + Tailwind v4) |
| **Optional Slices** | Refine-User-Management · Slack-Clone realtime chat |
| **Stack** | Next.js 14 / App Router · Supabase Postgres + Auth · Refine · Tailwind · Vercel |

---
## 2. Bootstrap Monorepo ✅  
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
## 3. Database & Security ❌  
*Source: Play-Book §3*
1. **Tables** `members · teams · member_roles · activity_log`  
2. **RLS** Enable on all tables; policies mirror `owner/admin/member` roles.  
3. **Edge Function** `handle_new_user` → insert into `members` on signup.

---
## 4. Core Pages (Refine + shadcn) ❌  
*Source: Play-Book §4*
| Route | Implementation Notes |
|-------|----------------------|
| `/dashboard` | Refine `<Authenticated>` wrapper; KPI cards (shadcn `<Card>`). |
| `/profile`   | `useEditableTable` (Inferencer) for member profile. |
| `/resources` | Refine `<List>` + Storage file links. |
| `/billing`   | Optional Stripe slice from Next.js SaaS Starter. |
| `/admin/users` | Import Refine-User-Management pages; apply shadcn theme. |

---
## 5. Auth Flow ❌  
*Source: Play-Book §5*
- Supabase email-link + OAuth already wired by starter.  
- Replace stock screens with shadcn forms.  
- Feed Supabase `session` to Refine `authProvider`.

---
## 6. Deployment & Developer Experience ✅  
*Source: Play-Book §6*
| Task | Tooling |
|------|---------|
| Link project | `vercel link` (root dir =`apps/dashboard`) |
| Env management | `vercel env add` · devs run `vercel pull` |
| GitHub Action | Lint-only (already implemented) |
| Previews | Vercel PR previews auto-enabled |
| DB migrations | `supabase db push`, store SQL in `supabase/migrations/` |
| Optional Storybook | `npx sb init` + shadcn stories |

---
## 7. Optional Feature Slices 🚧  
*Source: Play-Book §7*
1. **Realtime Chat** – copy slack-clone tables + hooks, wrap in Refine resources.  
2. **Notifications** – Edge Functions + database triggers.  
3. **Usage Analytics** – `activity_log` + Refine charts.

---
## 8. Aggressive Timeline ❌  
*Source: Play-Book §8*  (≈ 10 focused hours)
| Day | Deliverable | Status |
|-----|-------------|--------|
| 0 | Project scaffold (Steps A-C) – 1 h | ✅ DONE |
| 1 | DB schema + RLS – 2 h | ❌ PENDING |
| 1 | Auth UI swap to shadcn – 1 h | ❌ PENDING |
| 2 | Dashboard + Profile pages – 3 h | ❌ PENDING |
| 2 | Admin Users import – 1 h | ❌ PENDING |
| 3 | Polish, Vercel prod deploy – 2 h | ✅ DONE |

---
## 9. Issue / PR Workflow ✅  
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
### Next Steps ❌
1. Spin up Supabase project and grab env vars.  
2. ~~Run bootstrap commands (Section 2).~~  
3. Confirm auth round-trip works.  
4. Proceed with DB & page scaffolding per timeline.

---
## 11. Monorepo Tidy-Up Implementation ✅
*Added based on feature-starter integrations*

When integrating multiple starter templates (Supabase Starter, SaaS-Starter, Update-Starter, Partner-Gallery), we need a scalable approach to code organization. A monorepo structure is recommended for the following reasons:

- Clean separation of apps vs. shared code
- Ability to cherry-pick features from each starter without duplicating code
- Easy integration of Stripe billing, search functionality, and other components
- Future-proofing for adding marketing sites or additional apps

### Monorepo Setup Steps - Progress Update

| Step | What to do | Status | Notes |
|------|-------------|-------|-------|
| **1. Promote root to a workspace manager** | • Move the current `my-app/` to `apps/dashboard/`<br>• Create root `package.json` with `"workspaces": ["apps/*","packages/*"]` | ✅ DONE | Root package.json now includes proper workspace configuration |
| **2. Initialize Turborepo** | `npx turbo init` → creates `turbo.json` | ✅ DONE | Updated to Turborepo v2.x format using `tasks` instead of `pipeline` |
| **3. Extract shared bits** | `packages/ui` (shadcn components)<br>`packages/db` (Supabase client & Zod schemas)<br>`packages/config` (ESLint / Tailwind / tsconfig bases) | ✅ DONE | Created package structure with proper dependencies |
| **4. Vendor feature slices** | • Copy SaaS-Starter's Stripe billing logic into `packages/billing`<br>• Copy Partner-Gallery's media/search helpers into `packages/gallery` | ✅ DONE | Added skeleton implementations for both packages with proper interfaces |
| **5. Remove duplicate root files** | Delete root `postcss.config.mjs`, `next.config.ts`, etc. (they now live in packages or apps) | ✅ DONE | Cleaned up root directory |
| **6. Update scripts & CI** | Root `package.json`:<br>`"dev":"turbo run dev --parallel"`<br>`"build":"turbo run build"`<br>GitHub Action runs `turbo run lint` | ✅ DONE | Package scripts set up for monorepo management |
| **7. Configure Vercel** | Set Vercel production directory to `apps/dashboard` | ✅ DONE | Production deployment configured correctly |
| **8. Env-vars & secrets** | `vercel env add` per scope; devs run `vercel pull` | ✅ DONE | GitHub secrets added for Vercel deployments |

### Next Implementation Tasks

1. **Component Development** ❌
   - Add real shadcn component implementations to `packages/ui`
   - Create proper component documentation

2. **Integration** ❌
   - Update the dashboard app to import from shared packages
   - Verify imports work correctly across the monorepo

3. **Testing & Validation** ❌
   - Add proper testing infrastructure
   - Ensure build processes work correctly

### Current Monorepo Structure ✅
```
nova/
├── apps/
│   └── dashboard/     # Next.js dashboard application (previously my-app)
├── packages/
│   ├── ui/            # Shared UI components using shadcn/ui
│   ├── db/            # Database client & schema types
│   ├── config/        # Shared configurations (ESLint, Tailwind, TS)
│   ├── billing/       # Stripe integration
│   └── gallery/       # Media gallery and search features
├── turbo.json         # Turborepo configuration
└── package.json       # Root workspace configuration
```

All packages include proper TypeScript setup with proper module boundaries. The monorepo structure now allows code sharing between applications while maintaining separation of concerns.

---
## 12. Implementation Priorities
Based on current progress, these are the next immediate tasks:

1. **Database Schema** ❌
   - Implement base tables (members, teams, roles, activity_log)
   - Configure RLS policies
   - Test database functions

2. **Auth Flow** ❌
   - Implement shadcn-styled auth screens
   - Connect Supabase auth with Refine provider

3. **Core UI Pages** ❌
   - Build dashboard with KPI cards
   - Create profile edit forms
   - Implement resource listing pages

4. **Component Library Completion** 🚧
   - Move shadcn implementations to shared package
   - Create reusable component patterns