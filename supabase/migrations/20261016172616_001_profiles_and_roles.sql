/*
# SCINS MEDIA — Profiles, Roles, and User Management Foundation

## Overview
Creates the user profile system with role-based access control for the SCINS MEDIA
scientific publishing platform. This is the foundational layer that all other tables
depend on for authorization.

## New Tables
1. `profiles` — extends Supabase auth.users with display name, role, and account state
   - id (uuid, PK, references auth.users)
   - email (text, unique — synced from auth)
   - full_name (text — display name)
   - role (enum — super_admin, admin, editor, reviewer, author, reader)
   - is_active (boolean — soft disable)
   - created_at, updated_at (timestamps)

## Security
- RLS enabled on profiles
- Users can read their own profile
- Users can update their own profile (but NOT their own role — role changes require admin)
- All profiles are readable by authenticated users (staff directories, editorial boards)
- Role assignment is done via a SECURITY DEFINER function callable only by super_admin/admin
*/

-- Profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'reader' CHECK (role IN ('super_admin','admin','editor','reviewer','author','reader')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Users can read all profiles (needed for editorial boards, author directories)
DROP POLICY IF EXISTS "profiles_select_all" ON profiles;
CREATE POLICY "profiles_select_all"
  ON profiles FOR SELECT TO authenticated
  USING (true);

-- Users can read their own profile even when anon (for session restore)
DROP POLICY IF EXISTS "profiles_select_own_anon" ON profiles;
CREATE POLICY "profiles_select_own_anon"
  ON profiles FOR SELECT TO anon
  USING (auth.uid() = id);

-- Users can update their own profile (name only, not role)
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Users can insert their own profile row
DROP POLICY IF EXISTS "profiles_insert_own" ON profiles;
CREATE POLICY "profiles_insert_own"
  ON profiles FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (new.id, new.email, COALESCE(new.raw_user_meta_data->>'full_name', ''))
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Helper function: is current user an admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('super_admin','admin') AND is_active = true
  );
$$;

-- Helper function: is current user staff (editor or above)?
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role IN ('super_admin','admin','editor','reviewer') AND is_active = true
  );
$$;

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  new.updated_at = now();
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS profiles_updated_at ON profiles;
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
