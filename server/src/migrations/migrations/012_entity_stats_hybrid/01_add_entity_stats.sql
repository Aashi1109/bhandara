ALTER TABLE "Events"
ADD COLUMN IF NOT EXISTS "stats" JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE "Threads"
ADD COLUMN IF NOT EXISTS "stats" JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE "Messages"
ADD COLUMN IF NOT EXISTS "stats" JSONB NOT NULL DEFAULT '{}'::JSONB;

UPDATE "Events" e
SET "stats" = jsonb_build_object(
  'reactionCount',
  COALESCE((
    SELECT COUNT(*)
    FROM "Reactions" r
    WHERE r."contentId" = 'events/' || e."id"
      AND r."deletedAt" IS NULL
  ), 0),
  'threadCount',
  COALESCE((
    SELECT COUNT(*)
    FROM "Threads" t
    WHERE t."eventId" = e."id"
      AND t."deletedAt" IS NULL
  ), 0),
  'participantCount',
  COALESCE((
    SELECT COUNT(*)
    FROM jsonb_array_elements(COALESCE(e."participants", '[]'::JSONB)) AS participant
    WHERE COALESCE(participant->>'status', '') <> 'declined'
  ), 0),
  'verifierCount',
  jsonb_array_length(COALESCE(e."verifiers", '[]'::JSONB)),
  'mediaCount',
  jsonb_array_length(COALESCE(e."media", '[]'::JSONB)),
  'tagCount',
  jsonb_array_length(COALESCE(e."tags", '[]'::JSONB))
);

UPDATE "Threads" t
SET "stats" = jsonb_build_object(
  'reactionCount',
  COALESCE((
    SELECT COUNT(*)
    FROM "Reactions" r
    WHERE r."contentId" = 'threads/' || t."id"
      AND r."deletedAt" IS NULL
  ), 0),
  'messageCount',
  COALESCE((
    SELECT COUNT(*)
    FROM "Messages" m
    WHERE m."threadId" = t."id"
      AND m."deletedAt" IS NULL
  ), 0)
);

UPDATE "Messages" m
SET "stats" = jsonb_build_object(
  'reactionCount',
  COALESCE((
    SELECT COUNT(*)
    FROM "Reactions" r
    WHERE r."contentId" = 'messages/' || m."id"
      AND r."deletedAt" IS NULL
  ), 0),
  'replyCount',
  COALESCE((
    SELECT COUNT(*)
    FROM "Messages" child
    WHERE child."parentId" = m."id"
      AND child."deletedAt" IS NULL
  ), 0)
);
