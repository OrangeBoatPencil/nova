// Database schema types

export interface Member {
  id: string;
  auth_id: string | null;
  email: string;
  full_name: string | null;
  display_name: string | null;
  avatar_url: string | null;
  created_at: string;
  updated_at: string;
  last_sign_in: string | null;
}

export interface Team {
  id: string;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
  created_by: string | null;
}

export interface MemberRole {
  id: string;
  member_id: string;
  team_id: string;
  role: 'owner' | 'admin' | 'member';
  created_at: string;
  updated_at: string;
}

export interface ActivityLog {
  id: string;
  member_id: string | null;
  team_id: string | null;
  action: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  metadata: Record<string, any> | null;
  created_at: string;
} 