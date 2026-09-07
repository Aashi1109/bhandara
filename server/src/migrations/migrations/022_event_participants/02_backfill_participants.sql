-- Participants first. DISTINCT ON collapses duplicate entries for the same user
-- (the JSONB arrays had no uniqueness constraint), preferring a non-declined row.
INSERT INTO "EventParticipants" ("id", "eventId", "userId", "status", "createdAt", "updatedAt")
SELECT DISTINCT ON (e."id", p->>'user')
    uuidv7(),
    e."id",
    (p->>'user')::UUID,
    COALESCE(NULLIF(p->>'status', ''), 'pending')::"enum_EventParticipants_status",
    e."createdAt",
    e."createdAt"
FROM "Events" e
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(e."participants", '[]'::JSONB)) AS p
WHERE p->>'user' IS NOT NULL
ORDER BY e."id", p->>'user', (p->>'status' = 'declined')
ON CONFLICT ("eventId", "userId") DO NOTHING;

-- Then verifiers. Verification was previously open to non-participants, so a
-- verifier with no participation row becomes a confirmed participant. Existing
-- rows keep their status; only "verifiedAt" is filled in, and never overwritten.
INSERT INTO "EventParticipants" ("id", "eventId", "userId", "status", "verifiedAt", "createdAt", "updatedAt")
SELECT DISTINCT ON (e."id", v->>'user')
    uuidv7(),
    e."id",
    (v->>'user')::UUID,
    'confirmed'::"enum_EventParticipants_status",
    COALESCE((v->>'verifiedAt')::TIMESTAMPTZ, NOW()),
    e."createdAt",
    NOW()
FROM "Events" e
CROSS JOIN LATERAL jsonb_array_elements(COALESCE(e."verifiers", '[]'::JSONB)) AS v
WHERE v->>'user' IS NOT NULL
ORDER BY e."id", v->>'user', (v->>'verifiedAt')::TIMESTAMPTZ
ON CONFLICT ("eventId", "userId")
DO UPDATE SET "verifiedAt" = COALESCE("EventParticipants"."verifiedAt", EXCLUDED."verifiedAt");
