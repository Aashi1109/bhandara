-- participantCount / verifierCount were derived from jsonb_array_length in
-- 012_entity_stats_hybrid. Recompute them from the table so the persisted
-- snapshot matches what the service now reads.
UPDATE "Events" e
SET "stats" = COALESCE(e."stats", '{}'::JSONB) || jsonb_build_object(
    'participantCount', (
        SELECT COUNT(*)
        FROM "EventParticipants" ep
        WHERE ep."eventId" = e."id" AND ep."status" <> 'declined'
    ),
    'verifierCount', (
        SELECT COUNT(*)
        FROM "EventParticipants" ep
        WHERE ep."eventId" = e."id" AND ep."verifiedAt" IS NOT NULL
    )
);
