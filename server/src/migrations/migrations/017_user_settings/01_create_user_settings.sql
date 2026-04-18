CREATE TABLE IF NOT EXISTS "UserSettings" (
  "id"            UUID        PRIMARY KEY DEFAULT uuidv7(),
  "userId"        UUID        NOT NULL UNIQUE REFERENCES "Users"("id") ON DELETE CASCADE,
  "notifications" JSONB       NOT NULL DEFAULT '{"events":true,"chat":true,"replies":true,"reminders":true}'::JSONB,
  "privacy"       JSONB       NOT NULL DEFAULT '{"shareLocation":false}'::JSONB,
  "onboarding"    JSONB       NOT NULL DEFAULT '{"hasOnboarded":false}'::JSONB,
  "interests"     TEXT[]      NOT NULL DEFAULT '{}',
  "createdAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "user_settings_userId_idx" ON "UserSettings"("userId");
