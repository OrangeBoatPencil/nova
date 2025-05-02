-- Initial schema for Nova Member Dashboard
-- Created on 2025-05-02

-- Enable PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- MEMBERS table
CREATE TABLE IF NOT EXISTS members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id UUID UNIQUE REFERENCES auth.users (id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT,
  display_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  last_sign_in TIMESTAMP WITH TIME ZONE
);

-- TEAMS table
CREATE TABLE IF NOT EXISTS teams (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  created_by UUID REFERENCES members(id) ON DELETE SET NULL
);

-- MEMBER_ROLES table (join table with role info)
CREATE TABLE IF NOT EXISTS member_roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID REFERENCES members(id) ON DELETE CASCADE NOT NULL,
  team_id UUID REFERENCES teams(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  UNIQUE(member_id, team_id)
);

-- ACTIVITY_LOG table
CREATE TABLE IF NOT EXISTS activity_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  member_id UUID REFERENCES members(id) ON DELETE SET NULL,
  team_id UUID REFERENCES teams(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Set up Row Level Security (RLS)
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Members can view their own profile
CREATE POLICY "Members can view own profile" 
  ON members FOR SELECT 
  USING (auth.uid() = auth_id);

-- Admin users can view all members
CREATE POLICY "Admins can view all members" 
  ON members FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM member_roles 
      WHERE member_roles.member_id = (SELECT id FROM members WHERE auth_id = auth.uid()) 
      AND member_roles.role IN ('admin', 'owner')
    )
  );

-- Members can view teams they belong to
CREATE POLICY "Members can view teams they belong to" 
  ON teams FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM member_roles 
      WHERE member_roles.team_id = teams.id 
      AND member_roles.member_id = (SELECT id FROM members WHERE auth_id = auth.uid())
    )
  );

-- Only admins can create teams
CREATE POLICY "Admins can create teams" 
  ON teams FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM member_roles 
      WHERE member_roles.member_id = (SELECT id FROM members WHERE auth_id = auth.uid()) 
      AND member_roles.role IN ('admin', 'owner')
    )
  );

-- Team owners/admins can update team details
CREATE POLICY "Team owners and admins can update team details" 
  ON teams FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM member_roles 
      WHERE member_roles.team_id = teams.id 
      AND member_roles.member_id = (SELECT id FROM members WHERE auth_id = auth.uid()) 
      AND member_roles.role IN ('admin', 'owner')
    )
  );

-- Team owners can delete teams
CREATE POLICY "Team owners can delete teams" 
  ON teams FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM member_roles 
      WHERE member_roles.team_id = teams.id 
      AND member_roles.member_id = (SELECT id FROM members WHERE auth_id = auth.uid()) 
      AND member_roles.role = 'owner'
    )
  );

-- Set up authentication triggers
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.members (auth_id, email, full_name, avatar_url)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();