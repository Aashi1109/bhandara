-- SQL Migration: Rename 'authProvider' to 'provider' in users meta JSONB column

-- 1. Update top-level 'authProvider' to 'provider'
-- 2. Update nested 'auth.authProvider' to 'auth.provider'
-- 3. Remove old 'authProvider' keys

UPDATE "Users"
SET meta = jsonb_set(
  meta,
  '{auth}',
  (
    (meta->'auth')::jsonb - 'authProvider'
  ) || jsonb_build_object(
    'provider',
    meta->'auth'->'authProvider'
  )
)
WHERE meta->'auth' ? 'authProvider';
