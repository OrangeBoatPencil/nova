# Member Dashboard – Implementation Plan

## 0 Repository & Project Meta
| Item | Value |
|------|-------|
| Main repo | `github.com/OrangeBoatPencil/nova` (forked from Vercel × Supabase Starter) |
| Project board | `GitHub Projects → Member Dashboard` |
| Branch strategy | `main` (protected) + short-lived feature branches |
| Deployment target | Vercel (linked to `main`) |

---

## 1 Phase-by-Phase Task List

### Phase 1 ─ Scaffold & Tooling
1. Clone starter and install deps  
2. Configure env vars (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, etc.)  
3. Bootstrap Refine (`@refinedev/cli add inferencer supabase`)  
4. Init shadcn/ui (`npx shadcn-ui init`)  
5. Commit baseline (`chore: scaffold app stack`)

### Phase 2 ─ Database & Security
1. Design `members`, `teams`, `member_roles`, `activity_log` tables  
2. Write SQL migrations via `supabase/migrations` folder  
3. Enable Row-Level Security on all new tables  
4. Policies for `owner`, `member`, `admin` roles  
5. Smoke-test CRUD with Supabase Studio

### Phase 3 ─ Auth UX
1. Replace template auth screens with shadcn forms  
2. Wire Supabase session into Refine `authProvider`  
3. Add social logins if desired (Google, GitHub)  
4. E2E flow test (sign-up → protected page)

### Phase 4 ─ Core Member Pages
| Route        | Tasks |
|--------------|-------|
| /dashboard   | KPI cards, upcoming events; Refine `<Authenticated>` wrapper |
| /profile     | Self-edit profile with Refine Inferencer |
| /resources   | List downloadable docs/videos |
| /billing ∗   | (Optional) Import Stripe slice from Next-SaaS Starter |

### Phase 5 ─ Admin Area
1. Import "Refine User-Management" pages  
2. Apply shadcn styling tokens  
3. Protect with role `admin`

### Phase 6 ─ Realtime & Notifications (Stretch)
1. Integrate Supabase Realtime for toast notifications  
2. (Option) Chat slice from Slack-Clone example

### Phase 7 ─ CI/CD & QA
1. Connect repo to Vercel (Preview → Prod)  
2. Add GitHub Actions for lint / type-check / tests  
3. Storybook for UI components (optional)  
4. End-to-end Playwright tests for critical paths

---

## 2 Milestones & Timeline (Aggressive)

| Day | Milestone |
|-----|-----------|
| 0   | Scaffold running locally & pushed |
| 1   | DB schema + RLS complete |
| 2   | Auth UX swapped to shadcn |
| 3   | Core member pages functional |
| 4   | Admin area integrated |
| 5   | Vercel prod deploy, smoke-tested |

---

## 3 Conversion to GitHub Issues

Create one epic per phase; under each, add the numbered tasks as Issues tagged with:
```
labels: [phase-x, type:feature]
projects: Member Dashboard
assignees: <your-team>
```
Link PRs to issues with "Closes #<n>". 