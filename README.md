# Nova - Member Dashboard

A community member dashboard built with Next.js, Refine.dev, Supabase, and shadcn/ui.

## Features

- 🔐 Authentication with Supabase Auth
- 👥 Team management
- 📊 Member dashboard
- 📚 Resource library
- 🛡️ Role-based access control
- 📱 Responsive UI with shadcn/ui
- 🔄 CRUD operations with Refine.dev

## Tech Stack

- **Framework**: [Next.js](https://nextjs.org/)
- **Data Provider**: [Supabase](https://supabase.io/)
- **Admin UI Framework**: [Refine.dev](https://refine.dev/)
- **UI Components**: [shadcn/ui](https://ui.shadcn.com/)
- **Authentication**: Supabase Auth
- **Database**: PostgreSQL (via Supabase)
- **Styling**: Tailwind CSS

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- A Supabase account

### Setup

1. Clone the repository

```bash
git clone https://github.com/OrangeBoatPencil/nova.git
cd nova/my-app
```

2. Install dependencies

```bash
npm install
```

3. Set up environment variables

Create a `.env.local` file in the `my-app` directory with the following variables:

```
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-supabase-anon-key
NEXT_PUBLIC_APP_URL=http://localhost:3000
```

4. Run the database migrations

You can use the Supabase CLI or apply the SQL migrations directly from the Supabase dashboard:

```bash
npx supabase login
npx supabase link --project-ref your-project-ref
npx supabase db push
```

Alternatively, you can copy the contents of `supabase/migrations/20250502_initial_schema.sql` and run them in the Supabase SQL editor.

5. Start the development server

```bash
npm run dev
```

6. Open [http://localhost:3000](http://localhost:3000) in your browser

## Project Structure

The application is located in the `my-app` directory with the following structure:

```
my-app/
├── src/
│   ├── app/                # Next.js app directory
│   │   ├── dashboard/      # Dashboard routes
│   │   ├── login/          # Authentication routes
│   │   └── register/       # User registration
│   ├── components/         # React components
│   │   ├── ui/             # shadcn UI components
│   │   └── RefineProvider.tsx  # Refine.dev provider
│   ├── lib/                # Utility functions
│   │   └── supabase.ts     # Supabase client
│   └── refine/             # Refine.dev configuration
│       ├── authProvider.ts # Auth provider
│       └── config.ts       # Resources and data provider
└── supabase/               # Supabase configuration
    └── migrations/         # Database migrations
```

## Deployment

This project can be deployed to Vercel by linking your GitHub repository:

1. Push your code to GitHub
2. Import your project in Vercel
3. Set the required environment variables
4. Deploy

## License

This project is licensed under the MIT License - see the LICENSE file for details.