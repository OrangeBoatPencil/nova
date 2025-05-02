# Supabase Setup Guide

This document outlines the required Supabase configuration for the Nova Dashboard.

## Project Configuration

1. **Create a Supabase Project**

   - Go to [Supabase Dashboard](https://app.supabase.io/)
   - Click "New project"
   - Enter project details

2. **Database Schema**
   - Apply migrations from `supabase/migrations/` directory
   - Run: `supabase db push` with CLI or execute SQL manually

## Authentication

1. **Email Authentication**

   - Enable "Email" provider in Authentication settings
   - Configure "Site URL" to match your Vercel production URL

2. **OAuth Providers (Optional)**
   - Configure additional providers as needed (Google, GitHub, etc.)
   - Set redirect URLs to include production and preview domains

## Row-Level Security (RLS)

1. **Enable RLS on All Tables**

   - Enable RLS for `members`, `teams`, `member_roles`, `activity_log`

2. **RLS Policies**
   - **Members Table**: Users can read/update their own data; admins can read all
   - **Teams Table**: Team members can read their teams; owners/admins can update
   - **Roles Table**: Team members can view roles; owners can change roles
   - **Activity Log**: Entries visible to team members they belong to

## API Keys

Store these securely; never commit to repository:

1. **Project URL**

   - Found in Project Settings → API
   - Format: `https://your-project.supabase.co`

2. **API Keys**
   - **Anon Key**: For client-side requests (public)
   - **Service Role Key**: For server-side operations (private)
   - Found in Project Settings → API

## Local Development

1. **Local .env.local File**

   - Create in `apps/dashboard/.env.local`
   - Add Supabase URL and anon key

2. **Supabase CLI (Optional)**
   - Install: `npm install -g supabase`
   - Login: `supabase login`
   - Link: `supabase link --project-ref your-project-ref`

## Migrations

1. **Creating Migrations**

   ```bash
   # Generate a migration file
   supabase migration new migration_name

   # Apply all migrations
   supabase db push
   ```

2. **Migration Standards**
   - Create one migration per feature
   - Include RLS policies in migrations
   - Test migrations locally before pushing
