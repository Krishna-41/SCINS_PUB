/*
# SCINS MEDIA — Storage Bucket Policies

## Overview
Sets up Row Level Security policies on the two storage buckets:
- `public-assets` (public read, admin write) — covers, logos, banners, images
- `private-files` (authenticated read, admin write) — manuscripts, supplementary files

## Security
- Public bucket: anyone can read, only admin can write
- Private bucket: only authenticated users can read (for manuscript access), only admin can write
*/

-- Public bucket policies
DROP POLICY IF EXISTS "public_read_assets" ON storage.objects;
CREATE POLICY "public_read_assets"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'public-assets');

DROP POLICY IF EXISTS "admin_write_assets" ON storage.objects;
CREATE POLICY "admin_write_assets"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'public-assets' AND public.is_admin());

DROP POLICY IF EXISTS "admin_update_assets" ON storage.objects;
CREATE POLICY "admin_update_assets"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'public-assets' AND public.is_admin())
  WITH CHECK (bucket_id = 'public-assets' AND public.is_admin());

DROP POLICY IF EXISTS "admin_delete_assets" ON storage.objects;
CREATE POLICY "admin_delete_assets"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'public-assets' AND public.is_admin());

-- Private bucket policies
DROP POLICY IF EXISTS "auth_read_private" ON storage.objects;
CREATE POLICY "auth_read_private"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'private-files');

DROP POLICY IF EXISTS "admin_write_private" ON storage.objects;
CREATE POLICY "admin_write_private"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'private-files' AND public.is_admin());

DROP POLICY IF EXISTS "admin_update_private" ON storage.objects;
CREATE POLICY "admin_update_private"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'private-files' AND public.is_admin())
  WITH CHECK (bucket_id = 'private-files' AND public.is_admin());

DROP POLICY IF EXISTS "admin_delete_private" ON storage.objects;
CREATE POLICY "admin_delete_private"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'private-files' AND public.is_admin());
