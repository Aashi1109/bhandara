import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js";
import { Redis } from "https://esm.sh/@upstash/redis@1.35.0";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const redis = new Redis({
  url: Deno.env.get("UPSTASH_REDIS_REST_URL")!,
  token: Deno.env.get("UPSTASH_REDIS_REST_TOKEN")!,
});

const ENTITY_CONFIG = {
  events: {
    table: "Events",
    fields: [
      "reactionCount",
      "threadCount",
      "participantCount",
      "verifierCount",
      "mediaCount",
      "tagCount",
    ],
  },
  threads: {
    table: "Threads",
    fields: ["reactionCount", "messageCount"],
  },
  messages: {
    table: "Messages",
    fields: ["reactionCount", "replyCount"],
  },
} as const;

type EntityType = keyof typeof ENTITY_CONFIG;

type SyncEntityInput = {
  type: EntityType;
  id: string;
  stats?: Record<string, number>;
};

function normalizeStats(type: EntityType, raw: Record<string, unknown> | null | undefined) {
  const config = ENTITY_CONFIG[type];
  return config.fields.reduce((acc, field) => {
    const parsed = Number(raw?.[field] ?? 0);
    acc[field] = Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
    return acc;
  }, {} as Record<string, number>);
}

async function getStatsFromRedis(type: EntityType, id: string) {
  const key = `entity-stats:${type}:${id}:stats`;
  const raw = await redis.hgetall<Record<string, unknown>>(key);
  return normalizeStats(type, raw ?? {});
}

async function persistEntityStats(entity: SyncEntityInput) {
  const config = ENTITY_CONFIG[entity.type];
  const stats = entity.stats ? normalizeStats(entity.type, entity.stats) : await getStatsFromRedis(entity.type, entity.id);

  const { error } = await supabase.from(config.table).update({ stats }).eq("id", entity.id);
  if (error) {
    throw new Error(`Failed syncing ${entity.type}/${entity.id}: ${error.message}`);
  }

  return {
    type: entity.type,
    id: entity.id,
    stats,
  };
}

async function resolveEntities(body: { entities?: SyncEntityInput[]; type?: EntityType; ids?: string[] }) {
  if (body.entities?.length) {
    return body.entities;
  }

  if (body.type && body.ids?.length) {
    return body.ids.map((id) => ({ type: body.type!, id }));
  }

  throw new Error("Provide `entities` or `type` with `ids`.");
}

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json();
    const entities = await resolveEntities(body);
    const results = [];

    for (const entity of entities) {
      results.push(await persistEntityStats(entity));
    }

    return new Response(JSON.stringify({ synced: results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as { message?: string })?.message ?? "Unknown error" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
