import { getRedisConnection } from "@/connections/redis";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";
import type {
  IEntityEngagement,
  IEntityEngagementSummary,
  IEntityEngagementStats,
  IEntityRating,
  IEntityRatingHistogram,
} from "@/definitions/types";
import { get32BitMD5Hash } from "@/helpers";
import { Event } from "@/features/events/model";
import { Message } from "@/features/messages/model";
import { Thread } from "@/features/threads/model";
import { User } from "@/features/users/model";

import {
  SUPPORTED_ENGAGEMENT_ENTITY_TYPES,
  type SupportedEngagementEntityType,
} from "./constants";
import { EntityEngagement, EntityRating } from "./model";

const DEFAULT_HISTOGRAM: IEntityRatingHistogram = {
  "1": 0,
  "2": 0,
  "3": 0,
  "4": 0,
  "5": 0,
};

const DEFAULT_STATS: IEntityEngagementStats = {
  viewCount: 0,
  ratingCount: 0,
  ratingAverage: 0,
  ratingHistogram: { ...DEFAULT_HISTOGRAM },
};

type ViewerContext = {
  userId?: string | null;
  ip?: string | null;
  sessionId?: string | null;
  userAgent?: string | null;
};

class EntityEngagementService {
  private readonly redis = getRedisConnection();
  private readonly namespace = CACHE_NAMESPACE_CONFIG.Engagement.namespace;

  private getAggregateKey(entityType: string, entityId: string) {
    return `${this.namespace}:${entityType}:${entityId}:stats`;
  }

  private getViewDedupeKey(
    entityType: string,
    entityId: string,
    dayKey: string,
    viewerKey: string,
  ) {
    return `${this.namespace}:${entityType}:${entityId}:views:${dayKey}:${viewerKey}`;
  }

  private getHistogramField(value: number) {
    return `rating_${value}`;
  }

  private buildViewerKey(context: ViewerContext) {
    if (context.userId) {
      return `user:${context.userId}`;
    }

    const raw = [context.ip || "", context.sessionId || "", context.userAgent || ""]
      .filter(Boolean)
      .join("|");
    return `anon:${get32BitMD5Hash(raw || "anonymous")}`;
  }

  private normalizeHistogram(raw: Record<string, unknown> | null | undefined): IEntityRatingHistogram {
    return {
      "1": Math.max(0, Number(raw?.rating_1 ?? raw?.["1"] ?? 0) || 0),
      "2": Math.max(0, Number(raw?.rating_2 ?? raw?.["2"] ?? 0) || 0),
      "3": Math.max(0, Number(raw?.rating_3 ?? raw?.["3"] ?? 0) || 0),
      "4": Math.max(0, Number(raw?.rating_4 ?? raw?.["4"] ?? 0) || 0),
      "5": Math.max(0, Number(raw?.rating_5 ?? raw?.["5"] ?? 0) || 0),
    };
  }

  private calculateAverage(histogram: IEntityRatingHistogram, ratingCount?: number) {
    const count =
      ratingCount ??
      histogram["1"] +
        histogram["2"] +
        histogram["3"] +
        histogram["4"] +
        histogram["5"];

    if (count === 0) return 0;

    const total =
      histogram["1"] * 1 +
      histogram["2"] * 2 +
      histogram["3"] * 3 +
      histogram["4"] * 4 +
      histogram["5"] * 5;

    return Number((total / count).toFixed(2));
  }

  private normalizeStats(raw: Record<string, unknown> | null | undefined): IEntityEngagementStats {
    const histogram = this.normalizeHistogram(raw);
    const ratingCount = Math.max(
      0,
      Number(
        raw?.ratingCount ??
          histogram["1"] +
            histogram["2"] +
            histogram["3"] +
            histogram["4"] +
            histogram["5"],
      ) || 0,
    );

    return {
      viewCount: Math.max(0, Number(raw?.viewCount ?? 0) || 0),
      ratingCount,
      ratingAverage: this.calculateAverage(histogram, ratingCount),
      ratingHistogram: histogram,
    };
  }

  private async setCachedStats(entityType: string, entityId: string, stats: IEntityEngagementStats) {
    await this.redis.hset(this.getAggregateKey(entityType, entityId), {
      viewCount: stats.viewCount,
      ratingCount: stats.ratingCount,
      rating_1: stats.ratingHistogram["1"],
      rating_2: stats.ratingHistogram["2"],
      rating_3: stats.ratingHistogram["3"],
      rating_4: stats.ratingHistogram["4"],
      rating_5: stats.ratingHistogram["5"],
    });
    await this.redis.expire(
      this.getAggregateKey(entityType, entityId),
      CACHE_NAMESPACE_CONFIG.Engagement.ttl,
    );
  }

  private async getCachedStats(entityType: string, entityId: string) {
    const raw = await this.redis.hgetall<Record<string, unknown>>(
      this.getAggregateKey(entityType, entityId),
    );

    if (!raw || Object.keys(raw).length === 0) {
      return null;
    }

    return this.normalizeStats(raw);
  }

  private async readPersistedStats(entityType: string, entityId: string) {
    const row = (await EntityEngagement.findOne({
      where: { entityType, entityId },
      raw: true,
      attributes: ["stats"],
    })) as Pick<IEntityEngagement, "stats"> | null;

    if (!row?.stats) {
      return null;
    }

    return this.normalizeStats(row.stats as unknown as Record<string, unknown>);
  }

  private normalizeReview(review?: string | null) {
    const value = review?.trim();
    return value && value.length > 0 ? value : null;
  }

  private toSummary(
    stats: IEntityEngagementStats,
    currentRating?: Pick<IEntityRating, "value" | "review" | "updatedAt"> | null,
  ): IEntityEngagementSummary {
    return {
      ...stats,
      currentUserRating: currentRating?.value ?? null,
      currentUserReview: currentRating?.review ?? null,
      currentUserReviewedAt: currentRating?.updatedAt ?? null,
    };
  }

  private async getCurrentUserRating(
    entityType: string,
    entityId: string,
    userId?: string | null,
  ) {
    if (!userId) {
      return null;
    }

    return (await EntityRating.findOne({
      where: { entityType, entityId, userId },
      raw: true,
      attributes: ["value", "review", "updatedAt"],
    })) as Pick<IEntityRating, "value" | "review" | "updatedAt"> | null;
  }

  private async bootstrapFromRatings(
    entityType: string,
    entityId: string,
  ): Promise<IEntityEngagementStats> {
    const rows = (await EntityRating.findAll({
      where: { entityType, entityId },
      raw: true,
      attributes: ["value"],
    })) as Pick<IEntityRating, "value">[];

    const histogram = { ...DEFAULT_HISTOGRAM };
    rows.forEach((row) => {
      const key = String(row.value) as keyof IEntityRatingHistogram;
      if (key in histogram) {
        histogram[key] += 1;
      }
    });

    const ratingCount = rows.length;
    return {
      viewCount: 0,
      ratingCount,
      ratingAverage: this.calculateAverage(histogram, ratingCount),
      ratingHistogram: histogram,
    };
  }

  private async ensureCachedStats(entityType: string, entityId: string) {
    const cached = await this.getCachedStats(entityType, entityId);
    if (cached) {
      return cached;
    }

    const persisted = await this.readPersistedStats(entityType, entityId);
    if (persisted) {
      await this.setCachedStats(entityType, entityId, persisted);
      return persisted;
    }

    const bootstrapped = await this.bootstrapFromRatings(entityType, entityId);
    await this.setCachedStats(entityType, entityId, bootstrapped);
    return bootstrapped;
  }

  private async persistStats(entityType: string, entityId: string, stats: IEntityEngagementStats) {
    const existing = await EntityEngagement.findOne({
      where: { entityType, entityId },
    });

    if (!existing) {
      await EntityEngagement.create({
        entityType,
        entityId,
        stats,
      } as Partial<IEntityEngagement>);
      return;
    }

    await existing.update({ stats });
  }

  private async assertEntityExists(entityType: SupportedEngagementEntityType, entityId: string) {
    if (entityType === "events") {
      return !!(await Event.findByPk(entityId, { raw: true, attributes: ["id"] }));
    }

    if (entityType === "threads") {
      return !!(await Thread.findByPk(entityId, { raw: true, attributes: ["id"] }));
    }

    if (entityType === "messages") {
      return !!(await Message.findByPk(entityId, { raw: true, attributes: ["id"] }));
    }

    return !!(await User.findByPk(entityId, { raw: true, attributes: ["id"] }));
  }

  isSupportedEntityType(entityType: string): entityType is SupportedEngagementEntityType {
    return (SUPPORTED_ENGAGEMENT_ENTITY_TYPES as readonly string[]).includes(entityType);
  }

  async getStats(entityType: string, entityId: string, userId?: string | null) {
    const cached = await this.getCachedStats(entityType, entityId);
    if (cached) {
      return this.toSummary(
        cached,
        await this.getCurrentUserRating(entityType, entityId, userId),
      );
    }

    const persisted = await this.readPersistedStats(entityType, entityId);
    if (persisted) {
      await this.setCachedStats(entityType, entityId, persisted);
      return this.toSummary(
        persisted,
        await this.getCurrentUserRating(entityType, entityId, userId),
      );
    }

    const bootstrapped = await this.bootstrapFromRatings(entityType, entityId);
    await this.setCachedStats(entityType, entityId, bootstrapped);
    return this.toSummary(
      bootstrapped,
      await this.getCurrentUserRating(entityType, entityId, userId),
    );
  }

  async getStatsMap(entityType: string, entityIds: string[]) {
    const uniqueIds = Array.from(new Set(entityIds.filter(Boolean)));
    const stats = await Promise.all(
      uniqueIds.map(async (entityId) => [entityId, await this.getStats(entityType, entityId)] as const),
    );
    return Object.fromEntries(stats);
  }

  async trackView(
    entityType: SupportedEngagementEntityType,
    entityId: string,
    context: ViewerContext,
  ) {
    const stats = await this.ensureCachedStats(entityType, entityId);
    const viewerKey = this.buildViewerKey(context);
    const now = new Date();
    const dayKey = now.toISOString().slice(0, 10);
    const dedupeKey = this.getViewDedupeKey(entityType, entityId, dayKey, viewerKey);
    const secondsUntilDayEnd = Math.max(
      60,
      Math.floor(
        (Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1) -
          now.getTime()) /
          1000,
      ),
    );

    const result = await this.redis.set(dedupeKey, "1", {
      nx: true,
      ex: secondsUntilDayEnd,
    });

    if (!result) {
      return stats;
    }

    await this.redis.hincrby(this.getAggregateKey(entityType, entityId), "viewCount", 1);
    await this.redis.expire(
      this.getAggregateKey(entityType, entityId),
      CACHE_NAMESPACE_CONFIG.Engagement.ttl,
    );

    const next = {
      ...stats,
      viewCount: stats.viewCount + 1,
    };

    await this.persistStats(entityType, entityId, next);
    return next;
  }

  async setRating(
    entityType: SupportedEngagementEntityType,
    entityId: string,
    userId: string,
    value: number,
    review?: string | null,
  ) {
    if (value < 1 || value > 5) {
      throw new Error("Rating value must be between 1 and 5");
    }

    const exists = await this.assertEntityExists(entityType, entityId);
    if (!exists) {
      throw new Error("Entity not found");
    }

    const stats = await this.ensureCachedStats(entityType, entityId);
    const existing = (await EntityRating.findOne({
      where: { entityType, entityId, userId },
      raw: true,
    })) as IEntityRating | null;

    const normalizedReview = this.normalizeReview(review);

    if (existing?.value === value && (existing.review ?? null) === normalizedReview) {
      return this.toSummary(stats, {
        value: existing.value,
        review: existing.review ?? null,
        updatedAt: existing.updatedAt,
      });
    }

    if (existing) {
      await EntityRating.update(
        { value, review: normalizedReview },
        { where: { entityType, entityId, userId } },
      );
    } else {
      await EntityRating.create({
        entityType,
        entityId,
        userId,
        value,
        review: normalizedReview,
      } as Partial<IEntityRating>);
    }

    const histogram = { ...stats.ratingHistogram };
    let ratingCount = stats.ratingCount;

    if (existing) {
      histogram[String(existing.value) as keyof IEntityRatingHistogram] = Math.max(
        0,
        histogram[String(existing.value) as keyof IEntityRatingHistogram] - 1,
      );
      await this.redis.hincrby(
        this.getAggregateKey(entityType, entityId),
        this.getHistogramField(existing.value),
        -1,
      );
    } else {
      ratingCount += 1;
      await this.redis.hincrby(
        this.getAggregateKey(entityType, entityId),
        "ratingCount",
        1,
      );
    }

    histogram[String(value) as keyof IEntityRatingHistogram] += 1;
    await this.redis.hincrby(
      this.getAggregateKey(entityType, entityId),
      this.getHistogramField(value),
      1,
    );
    await this.redis.expire(
      this.getAggregateKey(entityType, entityId),
      CACHE_NAMESPACE_CONFIG.Engagement.ttl,
    );

    const next = {
      viewCount: stats.viewCount,
      ratingCount,
      ratingHistogram: histogram,
      ratingAverage: this.calculateAverage(histogram, ratingCount),
    };

    await this.persistStats(entityType, entityId, next);
    return this.toSummary(next, {
      value,
      review: normalizedReview,
      updatedAt: new Date(),
    });
  }

  async deleteRating(
    entityType: SupportedEngagementEntityType,
    entityId: string,
    userId: string,
  ) {
    const stats = await this.ensureCachedStats(entityType, entityId);
    const existing = (await EntityRating.findOne({
      where: { entityType, entityId, userId },
      raw: true,
    })) as IEntityRating | null;

    if (!existing) {
      return this.toSummary(stats, null);
    }

    await EntityRating.destroy({
      where: { entityType, entityId, userId },
    });

    const histogram = { ...stats.ratingHistogram };
    histogram[String(existing.value) as keyof IEntityRatingHistogram] = Math.max(
      0,
      histogram[String(existing.value) as keyof IEntityRatingHistogram] - 1,
    );
    const ratingCount = Math.max(0, stats.ratingCount - 1);

    await this.redis.hincrby(
      this.getAggregateKey(entityType, entityId),
      this.getHistogramField(existing.value),
      -1,
    );
    await this.redis.hincrby(
      this.getAggregateKey(entityType, entityId),
      "ratingCount",
      -1,
    );
    await this.redis.expire(
      this.getAggregateKey(entityType, entityId),
      CACHE_NAMESPACE_CONFIG.Engagement.ttl,
    );

    const next = {
      viewCount: stats.viewCount,
      ratingCount,
      ratingHistogram: histogram,
      ratingAverage: this.calculateAverage(histogram, ratingCount),
    };

    await this.persistStats(entityType, entityId, next);
    return this.toSummary(next, null);
  }

  async getRatings(
    entityType: SupportedEngagementEntityType,
    entityId: string,
  ) {
    const rows = (await EntityRating.findAll({
      where: { entityType, entityId },
      raw: true,
      order: [["updatedAt", "DESC"]],
    })) as IEntityRating[];

    if (rows.length === 0) {
      return [];
    }

    const uniqueUserIds = Array.from(new Set(rows.map((row) => row.userId)));
    const users = (await User.findAll({
      where: { id: uniqueUserIds },
      raw: true,
      attributes: ["id", "name", "profilePic"],
    })) as Array<Pick<typeof User.prototype, "id" | "name" | "profilePic">>;
    const usersById = Object.fromEntries(users.map((user) => [user.id, user]));

    return rows.map((row) => ({
      ...row,
      review: row.review ?? null,
      user: usersById[row.userId] ?? null,
    }));
  }
}

export default EntityEngagementService;
