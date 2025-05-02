import { createBrowserClient } from '@supabase/ssr';

/**
 * Returns a Supabase client configured for the **browser**.
 * Uses the public anon key ‑ suitable for Client Components.
 */
export function createBrowserSupabaseClient() {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY) {
    throw new Error('Supabase environment variables are not set');
  }
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  );
}

export type SupabaseBrowserClient = ReturnType<typeof createBrowserSupabaseClient>; 