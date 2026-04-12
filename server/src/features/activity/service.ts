import type { IActivity, IPaginationParams } from '@/definitions/types';
import { findAllWithPagination } from '@/utils/dbUtils';
import { Activity } from './model';
import { Op } from 'sequelize';
import UserService, { toUserMini } from '@/features/users/service';
import { EActivityVisibility } from './constants';
import {
  deleteActivityCache,
  deleteUserActivityCache,
  deleteUserUpdatesCache,
  getActivityCache,
  setActivityCache,
} from './helpers';

class ActivityService {
  private readonly userService: UserService;

  constructor() {
    this.userService = new UserService();
  }

  async getById(id: string): Promise<IActivity | null> {
    const cached = await getActivityCache(id);
    if (cached) return cached;

    const row = await Activity.findByPk(id, { raw: true });
    if (!row) return null;

    await setActivityCache(id, row as IActivity);
    return row as IActivity;
  }

  async create(data: Partial<IActivity>): Promise<IActivity> {
    const row = await Activity.create(data as any);
    const activity = row.toJSON() as IActivity;

    await Promise.all([
      setActivityCache(activity.id, activity),
      deleteUserActivityCache(activity.actorId),
      activity.recipientId ? deleteUserUpdatesCache(activity.recipientId) : Promise.resolve(),
    ]);

    return activity;
  }

  async getUserActivity(
    userId: string,
    pagination: Partial<IPaginationParams> = {},
    options: {
      includePrivate?: boolean;
      types?: string[];
    } = {},
  ) {
    const limit = pagination.limit ?? 10;
    const next = pagination.next ?? null;
    const includePrivate = options.includePrivate ?? false;

    const where: Record<string, any> = { actorId: userId };
    if (!includePrivate) where.visibility = EActivityVisibility.Public;
    if (options.types?.length) where.type = { [Op.in]: options.types };

    const data = await findAllWithPagination(Activity, { where }, pagination);

    const actorIds = Array.from(new Set((data.items || []).map((item) => item.actorId)));
    const recipientIds = Array.from(
      new Set((data.items || []).map((item) => item.recipientId).filter(Boolean)),
    ) as string[];

    const users = await this.userService.getUserProfiles([...actorIds, ...recipientIds], toUserMini);

    const populatedItems = (data.items || []).map((item) => ({
      ...item,
      actor: users[item.actorId] || null,
      recipient: item.recipientId ? users[item.recipientId] || null : null,
    }));

    const result = {
      items: populatedItems,
      pagination: data.pagination,
    };

    return result;
  }

  async getUserUpdates(
    userId: string,
    pagination: Partial<IPaginationParams> = {},
    options: {
      unreadOnly?: boolean;
      types?: string[];
    } = {},
  ) {
    const limit = pagination.limit ?? 10;
    const next = pagination.next ?? null;
    const unreadOnly = options.unreadOnly ?? false;

    const where: Record<string, any> = { recipientId: userId };

    if (unreadOnly) {
      where.readAt = { [Op.is]: null };
    }

    if (options.types?.length) {
      where.type = { [Op.in]: options.types };
    }

    const data = await findAllWithPagination(Activity, { where }, pagination);

    const actorIds = Array.from(new Set((data.items || []).map((item) => item.actorId)));
    const users = await this.userService.getUserProfiles(actorIds, toUserMini);

    const populatedItems = (data.items || []).map((item) => ({
      ...item,
      actor: users[item.actorId] || null,
    }));

    const result = {
      items: populatedItems,
      pagination: data.pagination,
    };

    return result;
  }

  async markAsRead(activityId: string, userId: string) {
    const row = await Activity.findOne({
      where: {
        id: activityId,
        recipientId: userId,
      },
    });

    if (!row) return null;

    await row.update({ readAt: new Date() });
    const updated = row.toJSON() as IActivity;

    await Promise.all([setActivityCache(updated.id, updated), deleteUserUpdatesCache(userId)]);

    return updated;
  }

  async markAllAsRead(userId: string) {
    await Activity.update(
      { readAt: new Date() },
      {
        where: {
          recipientId: userId,
          readAt: { [Op.is]: null },
        },
      },
    );

    await deleteUserUpdatesCache(userId);
    return true;
  }

  async delete(id: string): Promise<IActivity | null> {
    const row = await Activity.findByPk(id);
    if (!row) return null;
    const data = row.toJSON() as IActivity;

    await row.destroy();

    await Promise.all([
      deleteActivityCache(id),
      deleteUserActivityCache(data.actorId),
      data.recipientId ? deleteUserUpdatesCache(data.recipientId) : Promise.resolve(),
    ]);

    return data;
  }
}

export default ActivityService;
