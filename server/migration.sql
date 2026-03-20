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

CREATE INDEX IF NOT EXISTS "users_updatedAt_idx" ON "Users"("updatedAt");
CREATE INDEX IF NOT EXISTS "threads_updatedAt_idx" ON "Threads"("updatedAt");
CREATE INDEX IF NOT EXISTS "events_updatedAt_idx" ON "Events"("updatedAt");
CREATE INDEX IF NOT EXISTS "messages_updatedAt_idx" ON "Messages"("updatedAt");
CREATE INDEX IF NOT EXISTS "tags_updatedAt_idx" ON "Tags"("updatedAt");
CREATE INDEX IF NOT EXISTS "activities_updatedAt_idx" ON "Activities"("updatedAt");
CREATE INDEX IF NOT EXISTS "activities_actorId_updatedAt_idx" ON "Activities"("actorId", "updatedAt");
CREATE INDEX IF NOT EXISTS "activities_recipientId_updatedAt_idx" ON "Activities"("recipientId", "updatedAt");
