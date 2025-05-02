# Vercel Setup Guide

This document outlines the required Vercel configuration for the Nova Dashboard monorepo.

## Project Configuration

1. **Root Directory**

   - Set to: `apps/dashboard`
   - This ensures Vercel builds from the correct directory within the monorepo

2. **Framework Preset**

   - Ensure "Next.js" is selected

3. **Build Command**
   - Use the default: `next build`

## Environment Variables

Set up the following environment variables in your Vercel project:

| Name                            | Value                                                                                                                                                  | Scope                            |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`      | Your Supabase project URL                                                                                                                              | Production, Preview, Development |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Your Supabase anonymous key                                                                                                                            | Production, Preview, Development |
| `NEXT_PUBLIC_APP_URL`           | `https://your-production-domain.com` for Production<br>`https://your-preview-domain.vercel.app` for Preview<br>`http://localhost:3000` for Development | Production, Preview, Development |

## Git Integration

1. **Preview Deployments**

   - Enable preview deployments for pull requests
   - Configure preview branches as needed

2. **Production Deployments**
   - Set to deploy from the `main` branch

## Serverless Function Configuration

1. **Regions**
   - Select regions close to your user base
   - Recommended: `iad1` (N. Virginia) for US users

## Custom Domains

1. **Production Domain**

   - Add your primary domain
   - Configure DNS settings as instructed by Vercel

2. **Preview Domains**
   - Preview deployments will be available at:
   - `https://pr-{PR_NUMBER}-nova.vercel.app`

## Team Access

Ensure all team members have appropriate access to the Vercel project:

- Admins: Full access
- Developers: Member role (can deploy)
- Viewers: Can view deployments but not modify settings
