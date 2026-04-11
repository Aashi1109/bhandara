INSERT INTO "UserSettings" (
  "id",
  "userId",
  "notifications",
  "privacy",
  "onboarding",
  "interests"
)
SELECT
  uuidv7(),
  "id",
  jsonb_build_object(
    'events',    COALESCE((meta->'notificationPreferences'->>'events')::boolean,    true),
    'chat',      COALESCE((meta->'notificationPreferences'->>'chat')::boolean,      true),
    'replies',   COALESCE((meta->'notificationPreferences'->>'replies')::boolean,   true),
    'reminders', COALESCE((meta->'notificationPreferences'->>'reminders')::boolean, true)
  ),
  jsonb_build_object(
    'shareLocation', COALESCE((meta->>'shareLocation')::boolean, false)
  ),
  jsonb_build_object(
    'hasOnboarded', COALESCE((meta->>'hasOnboarded')::boolean, false)
  ),
  COALESCE(
    ARRAY(SELECT jsonb_array_elements_text(meta->'interests')),
    '{}'::TEXT[]
  )
FROM "Users"
ON CONFLICT ("userId") DO NOTHING;
