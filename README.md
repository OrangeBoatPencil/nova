# Nova Dashboard

A modern dashboard for member management and team collaboration, built with Next.js, Supabase, Refine, and shadcn/ui.

## Features

- **Authentication**: Email link and OAuth sign-in with Supabase
- **Member Management**: Admin tools for user management
- **Resource Library**: Shared files and resources
- **Team Collaboration**: Team-based access controls
- **Billing Integration**: Subscription management with Stripe

## Tech Stack

- **Frontend**: Next.js 14 (App Router)
- **UI**: shadcn/ui (Radix + Tailwind CSS)
- **Admin Framework**: Refine v4
- **Database**: Supabase Postgres
- **Authentication**: Supabase Auth
- **Build System**: Turborepo
- **Deployment**: Vercel

## Authentication architecture

The application relies **solely on Supabase Auth** (v2) and Refine's `authProvider` wrapper.

Key points:

| Layer               | File(s) / Location                                                | Purpose                                                                                 |
| ------------------- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------- | --------------- | ----------------- | ------------------------------------------------------ |
| Supabase clients    | `src/utils/supabase/client.ts`, `src/utils/supabase/server.ts`    | Browser and server clients configured with anon key & cookie management                 |
| Session refresh     | `src/utils/supabase/middleware.ts` wire-up in `src/middleware.ts` | Refreshes sessions on every request so SSR components always have user context          |
| Refine authProvider | `src/providers/auth-provider.ts`                                  | Implements login, register, logout, forgot-password, update-password, permissions, etc. |
| Public routes       | `src/app/(login                                                   | register                                                                                | forgot-password | reset-password)/` | Forms that call the authProvider **or** REST endpoints |
| Callback handler    | `src/app/auth/callback/route.ts`                                  | Converts OAuth or magic-link callbacks into a Supabase session                          |
| REST endpoints      | `src/app/api/auth/forgot-password` & `reset-password`             | Allow password flows without relying on Refine hooks                                    |
| Tests               | `tests/e2e/auth-flow.spec.ts`                                     | Playwright scenarios covering email, OAuth, password reset                              |

Supported flows:

1. **Email/password login** – `signInWithPassword`.
2. **OAuth (GitHub, Google)** – `signInWithOAuth` → `/auth/callback` → session.
3. **Registration** – `signUp` + email verification (redirect to `/auth/callback`).
4. **Forgot / reset password** – reset email to `/reset-password`; user sets new password which triggers `updateUser`.
5. **Sign-out** – `auth.signOut()`; middleware drops cookies.

No other auth frameworks (e.g., NextAuth, Clerk) are present.

## Monorepo Structure

```
nova/
├── apps/
│   └── dashboard/     # Next.js dashboard application
├── packages/
│   ├── ui/            # Shared UI components
│   ├── db/            # Database client & schemas
│   ├── config/        # Shared configurations
│   ├── billing/       # Billing integration
│   └── gallery/       # Media gallery features
└── ...
```

## Getting Started

### Prerequisites

- Node.js 18+
- npm 8+
- Supabase account
- Vercel account (optional for deployment)

### Installation

1. Clone the repository

```bash
git clone https://github.com/evca-team/nova.git
cd nova
```

2. Install dependencies

```bash
npm install
```

3. Set up environment variables

```bash
cp apps/dashboard/.env.example apps/dashboard/.env.local
# Edit .env.local with your Supabase credentials
```

4. Start the development server

```bash
npm run dev
```

5. Open [http://localhost:3000](http://localhost:3000) in your browser

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development guidelines.

## Deployment

This project is configured for deployment on Vercel. See our [Vercel setup guide](.github/VERCEL_SETUP.md) for instructions.

## Documentation

- [Supabase Setup](.github/SUPABASE_SETUP.md)
- [Branch Protection](.github/BRANCH_PROTECTION.md)
- [Vercel Setup](.github/VERCEL_SETUP.md)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
