import { CACHE_NAMESPACE_CONFIG, REDIS_CONNECTION_NAMES } from "@/constants";
import type {
  IBaseThread,
  IEvent,
  IEventStats,
  IMessage,
  IMessageStats,
  IThreadStats,
} from "@/definitions/types";
import RedisCache from "@/features/cache/redis";
import { EEventParticipantStatus } from "@/definitions/enums";
import { Event } from "@/features/events/model";
import { Thread } from "@/features/threads/model";
import { Message } from "@/features/messages/model";
import { Reaction } from "@/features/reactions/model";
import EntityEngagementService from "@/features/engagement/service";
import { cacheKeys } from "@/features/cache/keys";

type EntityType = "events" | "threads" | "messages";

type StatsByEntity = {
  events: IEventStats;
  threads: IThreadStats;
  messages: IMessageStats;
};

type NumericStatsRecord = Record<string, number>;

const DEFAULT_EVENT_STATS: IEventStats = {
  reactionCount: 0,
  threadCount: 0,
  participantCount: 0,
  verifierCount: 0,
  mediaCount: 0,
  tagCount: 0,
};

const DEFAULT_THREAD_STATS: IThreadStats = {
  reactionCount: 0,
  messageCount: 0,
};

const DEFAULT_MESSAGE_STATS: IMessageStats = {
  reactionCount: 0,
  replyCount: 0,
};

class EntityStatsService {
  private readonly cache = new RedisCache({
    connectionName: REDIS_CONNECTION_NAMES.Analytics,
    namespace: CACHE_NAMESPACE_CONFIG.EntityStats.namespace,
    defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.EntityStats.ttl,
  });
  private readonly entityEngagementService = new EntityEngagementService();

  private getKey(entityType: EntityType, id: string) {
    return cacheKeys.stats(entityType, id);
  }

  private getDefaults<T extends EntityType>(entityType: T): StatsByEntity[T] {
    if (entityType === "events") {
      return { ...DEFAULT_EVENT_STATS } as StatsByEntity[T];
    }

    if (entityType === "threads") {
      return { ...DEFAULT_THREAD_STATS } as StatsByEntity[T];
    }

    return { ...DEFAULT_MESSAGE_STATS } as StatsByEntity[T];
  }

  private normalizeStats<T extends Record<string, number>>(
    raw: Record<string, unknown> | null | undefined,
    defaults: T,
  ): T | null {
    if (!raw || Object.keys(raw).length === 0) {
      return null;
    }

    return Object.keys(defaults).reduce((acc, field) => {
      const rawValue = raw[field];
      const parsedValue =
        typeof rawValue === "number"
          ? rawValue
          : typeof rawValue === "string"
            ? Number(rawValue)
            : Number(defaults[field as keyof T]);
      acc[field as keyof T] = Number.isFinite(parsedValue)
        ? (Math.max(0, parsedValue) as T[keyof T])
        : defaults[field as keyof T];
      return acc;
    }, { ...defaults });
  }

  private normalizeEntityStats<T extends EntityType>(
    entityType: T,
    raw: Record<string, unknown> | null | undefined,
  ): StatsByEntity[T] | null {
    return this.normalizeStats(raw, this.getDefaults(entityType) as unknown as NumericStatsRecord) as unknown as
      | StatsByEntity[T]
      | null;
  }

  private async getCachedStats<T extends EntityType>(entityType: T, id: string): Promise<StatsByEntity[T] | null> {
    const cached = await this.cache.getHKeys(this.getKey(entityType, id));
    return this.normalizeEntityStats(entityType, cached as Record<string, unknown> | null);
  }

  private async setCachedStats<T extends EntityType>(entityType: T, id: string, stats: StatsByEntity[T]) {
    await this.cache.setHKeys(this.getKey(entityType, id), stats, this.cache.defaultTTLMs);
  }

  private async readPersistedStats<T extends EntityType>(entityType: T, id: string): Promise<StatsByEntity[T] | null> {
    if (entityType === "events") {
      const event = (await Event.findByPk(id, {
        raw: true,
        attributes: ["stats"],
      })) as Pick<IEvent, "stats"> | null;
      return this.normalizeEntityStats(entityType, (event?.stats ?? null) as unknown as Record<string, unknown> | null);
    }

    if (entityType === "threads") {
      const thread = (await Thread.findByPk(id, {
        raw: true,
        attributes: ["stats"],
      })) as Pick<IBaseThread, "stats"> | null;
      return this.normalizeEntityStats(entityType, (thread?.stats ?? null) as unknown as Record<string, unknown> | null);
    }

    const message = (await Message.findByPk(id, {
      raw: true,
      attributes: ["stats"],
    })) as Pick<IMessage, "stats"> | null;
    return this.normalizeEntityStats(entityType, (message?.stats ?? null) as unknown as Record<string, unknown> | null);
  }

  private async persistStats<T extends EntityType>(entityType: T, id: string, stats: StatsByEntity[T]) {
    if (entityType === "events") {
      await Event.update({ stats } as Partial<IEvent>, { where: { id } });
      return;
    }

    if (entityType === "threads") {
      await Thread.update({ stats } as Partial<IBaseThread>, { where: { id } });
      return;
    }

    await Message.update({ stats } as Partial<IMessage>, { where: { id } });
  }

  private async bootstrapEventStats(id: string): Promise<IEventStats> {
    const event = (await Event.findByPk(id, {
      raw: true,
      attributes: ["participants", "verifiers", "media", "tags"],
    })) as Pick<IEvent, "participants" | "verifiers" | "media" | "tags"> | null;

    if (!event) {
      return { ...DEFAULT_EVENT_STATS };
    }

    const [reactionCount, threadCount] = await Promise.all([
      Reaction.count({ where: { contentId: `events/${id}` } }),
      Thread.count({ where: { eventId: id } }),
    ]);

    return {
      reactionCount,
      threadCount,
      participantCount: (event.participants || []).filter(
        (participant) => participant.status !== EEventParticipantStatus.Declined,
      ).length,
      verifierCount: (event.verifiers || []).length,
      mediaCount: (event.media || []).length,
      tagCount: (event.tags || []).length,
    };
  }

  private async bootstrapThreadStats(id: string): Promise<IThreadStats> {
    const [reactionCount, messageCount] = await Promise.all([
      Reaction.count({ where: { contentId: `threads/${id}` } }),
      Message.count({ where: { threadId: id } }),
    ]);

    return { reactionCount, messageCount };
  }

  private async bootstrapMessageStats(id: string): Promise<IMessageStats> {
    const [reactionCount, replyCount] = await Promise.all([
      Reaction.count({ where: { contentId: `messages/${id}` } }),
      Message.count({ where: { parentId: id } }),
    ]);

    return { reactionCount, replyCount };
  }

  private async getOrBootstrap<T extends EntityType>(entityType: T, id: string): Promise<StatsByEntity[T]> {
    const cached = await this.getCachedStats(entityType, id);
    if (cached) {
      return cached;
    }

    const persisted = await this.readPersistedStats(entityType, id);
    if (persisted) {
      await this.setCachedStats(entityType, id, persisted);
      return persisted;
    }

    const bootstrapped =
      entityType === "events"
        ? ((await this.bootstrapEventStats(id)) as StatsByEntity[T])
        : entityType === "threads"
          ? ((await this.bootstrapThreadStats(id)) as StatsByEntity[T])
          : ((await this.bootstrapMessageStats(id)) as StatsByEntity[T]);

    await Promise.all([
      this.persistStats(entityType, id, bootstrapped),
      this.setCachedStats(entityType, id, bootstrapped),
    ]);

    return bootstrapped;
  }

  private async incrementCachedField<T extends EntityType>(
    entityType: T,
    id: string,
    field: keyof StatsByEntity[T],
    by: number,
  ) {
    const key = this.getKey(entityType, id);
    await this.cache.incrementHKey(key, field as string, by, this.cache.defaultTTLMs);

    if (by < 0) {
      const currentValue = await this.cache.getHKey(key, field as string);
      const parsedValue = typeof currentValue === "string" ? Number(currentValue) : Number(currentValue ?? 0);
      if (Number.isFinite(parsedValue) && parsedValue < 0) {
        await this.cache.setHKey(key, field as string, 0, this.cache.defaultTTLMs);
      }
    }
  }

  async getEventStats(id: string): Promise<IEventStats> {
    return this.getOrBootstrap("events", id);
  }

  async getThreadStats(id: string): Promise<IThreadStats> {
    return this.getOrBootstrap("threads", id);
  }

  async getMessageStats(id: string): Promise<IMessageStats> {
    return this.getOrBootstrap("messages", id);
  }

  async getEventStatsMap(ids: string[]) {
    const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
    const stats = await Promise.all(uniqueIds.map(async (id) => [id, await this.getEventStats(id)] as const));
    return Object.fromEntries(stats);
  }

  async getThreadStatsMap(ids: string[]) {
    const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
    const stats = await Promise.all(uniqueIds.map(async (id) => [id, await this.getThreadStats(id)] as const));
    return Object.fromEntries(stats);
  }

  async getMessageStatsMap(ids: string[]) {
    const uniqueIds = Array.from(new Set(ids.filter(Boolean)));
    const stats = await Promise.all(uniqueIds.map(async (id) => [id, await this.getMessageStats(id)] as const));
    return Object.fromEntries(stats);
  }

  async incrementEventStat(id: string, field: keyof IEventStats, by: number) {
    await this.incrementCachedField("events", id, field, by);
  }

  async incrementThreadStat(id: string, field: keyof IThreadStats, by: number) {
    await this.incrementCachedField("threads", id, field, by);
  }

  async incrementMessageStat(id: string, field: keyof IMessageStats, by: number) {
    await this.incrementCachedField("messages", id, field, by);
  }

  async setEventStats(id: string, stats: IEventStats, persist = false) {
    await this.setCachedStats("events", id, stats);
    if (persist) {
      await this.persistStats("events", id, stats);
    }
  }

  async setThreadStats(id: string, stats: IThreadStats, persist = false) {
    await this.setCachedStats("threads", id, stats);
    if (persist) {
      await this.persistStats("threads", id, stats);
    }
  }

  async setMessageStats(id: string, stats: IMessageStats, persist = false) {
    await this.setCachedStats("messages", id, stats);
    if (persist) {
      await this.persistStats("messages", id, stats);
    }
  }

  async syncEventRowStats(event: Pick<IEvent, "id" | "participants" | "verifiers" | "media" | "tags">, persist = false) {
    const current = await this.getEventStats(event.id);
    const next: IEventStats = {
      ...current,
      participantCount: (event.participants || []).filter(
        (participant) => participant.status !== EEventParticipantStatus.Declined,
      ).length,
      verifierCount: (event.verifiers || []).length,
      mediaCount: (event.media || []).length,
      tagCount: (event.tags || []).length,
    };

    await this.setEventStats(event.id, next, persist);
    return next;
  }

  async syncStatsSnapshot<T extends EntityType>(entityType: T, id: string, stats?: StatsByEntity[T]) {
    const snapshot = stats ?? (await this.getCachedStats(entityType, id)) ?? (await this.getOrBootstrap(entityType, id));
    await this.persistStats(entityType, id, snapshot);
    return snapshot;
  }

  async hydrateEvent<T extends IEvent>(event: T): Promise<T> {
    const [stats, engagement] = await Promise.all([
      this.getEventStats(event.id),
      this.entityEngagementService.getStats("events", event.id),
    ]);
    event.stats = {
      ...stats,
      viewCount: engagement.viewCount,
      ratingCount: engagement.ratingCount,
      ratingAverage: engagement.ratingAverage,
    };
    return event;
  }

  async hydrateEvents<T extends IEvent>(events: T[]): Promise<T[]> {
    if (events.length === 0) return events;
    const [statsMap, engagementMap] = await Promise.all([
      this.getEventStatsMap(events.map((event) => event.id)),
      this.entityEngagementService.getStatsMap("events", events.map((event) => event.id)),
    ]);
    events.forEach((event) => {
      const stats = statsMap[event.id] || DEFAULT_EVENT_STATS;
      const engagement = engagementMap[event.id];
      event.stats = {
        ...stats,
        viewCount: engagement?.viewCount ?? 0,
        ratingCount: engagement?.ratingCount ?? 0,
        ratingAverage: engagement?.ratingAverage ?? 0,
      };
    });
    return events;
  }

  async hydrateThread<T extends IBaseThread>(thread: T): Promise<T> {
    const [stats, engagement] = await Promise.all([
      this.getThreadStats(thread.id),
      this.entityEngagementService.getStats("threads", thread.id),
    ]);
    thread.stats = {
      ...stats,
      viewCount: engagement.viewCount,
      ratingCount: engagement.ratingCount,
      ratingAverage: engagement.ratingAverage,
    };
    return thread;
  }

  async hydrateThreads<T extends IBaseThread>(threads: T[]): Promise<T[]> {
    if (threads.length === 0) return threads;
    const [statsMap, engagementMap] = await Promise.all([
      this.getThreadStatsMap(threads.map((thread) => thread.id)),
      this.entityEngagementService.getStatsMap("threads", threads.map((thread) => thread.id)),
    ]);
    threads.forEach((thread) => {
      const stats = statsMap[thread.id] || DEFAULT_THREAD_STATS;
      const engagement = engagementMap[thread.id];
      thread.stats = {
        ...stats,
        viewCount: engagement?.viewCount ?? 0,
        ratingCount: engagement?.ratingCount ?? 0,
        ratingAverage: engagement?.ratingAverage ?? 0,
      };
    });
    return threads;
  }

  async hydrateMessage<T extends IMessage>(message: T): Promise<T> {
    const [stats, engagement] = await Promise.all([
      this.getMessageStats(message.id),
      this.entityEngagementService.getStats("messages", message.id),
    ]);
    message.stats = {
      ...stats,
      viewCount: engagement.viewCount,
      ratingCount: engagement.ratingCount,
      ratingAverage: engagement.ratingAverage,
    };
    return message;
  }

  async hydrateMessages<T extends IMessage>(messages: T[]): Promise<T[]> {
    if (messages.length === 0) return messages;
    const [statsMap, engagementMap] = await Promise.all([
      this.getMessageStatsMap(messages.map((message) => message.id)),
      this.entityEngagementService.getStatsMap("messages", messages.map((message) => message.id)),
    ]);
    messages.forEach((message) => {
      const stats = statsMap[message.id] || DEFAULT_MESSAGE_STATS;
      const engagement = engagementMap[message.id];
      message.stats = {
        ...stats,
        viewCount: engagement?.viewCount ?? 0,
        ratingCount: engagement?.ratingCount ?? 0,
        ratingAverage: engagement?.ratingAverage ?? 0,
      };
    });
    return messages;
  }
}

export default EntityStatsService;
