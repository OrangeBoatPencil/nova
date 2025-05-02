import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';

// Database schema types
export const MemberSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  name: z.string().optional(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export const TeamSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

export const MemberRoleSchema = z.object({
  id: z.string().uuid(),
  member_id: z.string().uuid(),
  team_id: z.string().uuid(),
  role: z.enum(['admin', 'member', 'owner']),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
});

// Type exports
export type Member = z.infer<typeof MemberSchema>;
export type Team = z.infer<typeof TeamSchema>;
export type MemberRole = z.infer<typeof MemberRoleSchema>;

// Create a Supabase client
export const createSupabaseClient = (
  supabaseUrl: string,
  supabaseKey: string
) => {
  return createClient(supabaseUrl, supabaseKey);
};

export type SupabaseClient = ReturnType<typeof createSupabaseClient>;