CREATE OR REPLACE FUNCTION create_event_with_associations(
  event_data JSONB,
  tag_ids UUID[],
  media_ids UUID[]
)
RETURNS "Events" AS $$
DECLARE
  new_event "Events";
BEGIN
  -- Step 1: Insert the Event
  INSERT INTO "Events" (
    "name",
    "description",
    "location",
    "participants",
    "verifiers",
    "type",
    "createdBy",
    "isDraft",
    "cancelledAt",
    "capacity",
    "tags",
    "media",
    "startTime",
    "endTime"
  )
  VALUES (
    event_data->>'name',
    event_data->>'description',
    COALESCE(event_data->'location', '{}'::JSONB),
    COALESCE(event_data->'participants', '[]'::JSONB),
    COALESCE(event_data->'verifiers', '[]'::JSONB),
    (event_data->>'type')::"EventType",
    (event_data->>'createdBy')::UUID,
    COALESCE((event_data->>'isDraft')::BOOLEAN, FALSE),
    NULLIF(event_data->>'cancelledAt', '')::TIMESTAMPTZ,
    NULLIF(event_data->>'capacity', '')::INTEGER,
    COALESCE(to_jsonb(tag_ids), '[]'::JSONB),
    COALESCE(to_jsonb(media_ids), '[]'::JSONB),
    CAST(event_data->>'startTime' AS TIMESTAMPTZ),
    CAST(event_data->>'endTime' AS TIMESTAMPTZ)
  )
  RETURNING * INTO new_event;

  -- Step 2: Create the Q&A Thread
  INSERT INTO "Threads" (
    "visibility",
    "lockHistory",
    "eventId",
    "createdBy"
  )
  VALUES (
    'public',
    '[]'::JSONB,
    new_event.id,
    (event_data->>'createdBy')::UUID
  );

  -- Step 3: Create the Discussion Thread
  INSERT INTO "Threads" (
    "visibility",
    "lockHistory",
    "eventId",
    "createdBy"
  )
  VALUES (
    'public',
    '[]'::JSONB,
    new_event.id,
    (event_data->>'createdBy')::UUID
  );

  -- Return the newly created Event
  RETURN new_event;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_tags_with_children()
RETURNS TABLE (
    id UUID,
    name TEXT,
    value TEXT,
    description TEXT,
    icon TEXT,
    color TEXT,
    parentId UUID,
    createdBy UUID,
    createdAt TIMESTAMPTZ,
    updatedAt TIMESTAMPTZ,
    deletedAt TIMESTAMPTZ,
    hasChildren BOOLEAN
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    t.*,
    COUNT(c.id) > 0 AS "hasChildren"
  FROM "Tags" t
  LEFT JOIN "Tags" c ON c."parentId" = t."id" AND c."deletedAt" IS NULL
  WHERE t."deletedAt" IS NULL
  GROUP BY t."id";
END;
$$ LANGUAGE plpgsql STABLE;
