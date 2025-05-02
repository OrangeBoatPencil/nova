# Nova - Member Dashboard Monorepo

A community member dashboard built with Next.js, Refine.dev, Supabase, and shadcn/ui, organized as a monorepo.

## Features

- 🔐 Authentication with Supabase Auth
- 👥 Team management
- 📊 Member dashboard
- 📚 Resource library
- 🛡️ Role-based access control
- 📱 Responsive UI with shadcn/ui
- 🔄 CRUD operations with Refine.dev
- 💰 Stripe integration (coming soon)

## Tech Stack

- **Framework**: [Next.js](https://nextjs.org/)
- **Monorepo Tool**: [Turborepo](https://turbo.build/)
- **Data Provider**: [Supabase](https://supabase.io/)
- **Admin UI Framework**: [Refine.dev](https://refine.dev/)
- **UI Components**: [shadcn/ui](https://ui.shadcn.com/)
- **Authentication**: Supabase Auth
- **Database**: PostgreSQL (via Supabase)
- **Styling**: Tailwind CSS

## Monorepo Structure

```
/
├── apps/                  # Applications
│   └── dashboard/         # Member dashboard (Next.js)
├── packages/              # Shared packages
│   ├── ui/                # UI components
│   ├── db/                # Database client and types
│   ├── billing/           # Stripe integration (planned)
│   ├── gallery/           # Media utilities (planned)
│   └── config/            # Shared configs
└── turbo.json             # Turborepo configuration
```

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- A Supabase account

### Setup

1. Clone the repository

```bash
git clone https://github.com/OrangeBoatPencil/nova.git
cd nova
```

2. Install dependencies

```bash
npm install
```

3. Set up environment variables

Create a `.env.local` file in the `apps/dashboard` directory with:

```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

4. Run the database migrations

```bash
npm run db:migrate
npm run db:seed
```

5. Start the development server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser

## Development Workflow

- **Run all apps and packages**: `npm run dev`
- **Build everything**: `npm run build`
- **Lint everything**: `npm run lint`
- **Clean all node_modules**: `npm run clean`

## Deployment

The dashboard application is deployed to Vercel:

1. Push your code to GitHub
2. Import project in Vercel (points to `apps/dashboard`)
3. Set the required environment variables
4. Deploy

## License

This project is licensed under the MIT License.