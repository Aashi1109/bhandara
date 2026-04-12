import type { IRequestPagination, ICustomRequest, IBaseUser } from '@/definitions/types';
import { bulkSetUserCache, getPublicUser, getSafeUser } from './helpers';
import UserService from './service';
import UserSettingsService from './settings.service';
import type { Request, Response } from 'express';
import { hasMeaningfulChange, isEmpty, omit } from '@/utils';
import { NotFoundError } from '@/exceptions';
import { Op } from 'sequelize';
import EntityEngagementService from '@/features/engagement/service';
import { emitSocketEvent } from '@/socket/emitter';
import { PLATFORM_SOCKET_EVENTS, REDIS_CONNECTION_NAMES } from '@/constants';
import { Event } from '@/features/events/model';
import { cacheKeys } from '@/features/cache/keys';
import { getRedisConnection } from '@/connections/redis';

const userService = new UserService();
const userSettingsService = new UserSettingsService();
const entityEngagementService = new EntityEngagementService();
const analyticsRedis = getRedisConnection(REDIS_CONNECTION_NAMES.Analytics);

const parseEngagementHash = (h: Record<string, string>) => {
  const rc = parseInt(h.ratingCount ?? '0', 10);
  const avg = rc > 0 ? [1, 2, 3, 4, 5].reduce((s, i) => s + i * parseInt(h[`rating_${i}`] ?? '0', 10), 0) / rc : 0;
  return {
    viewCount: parseInt(h.viewCount ?? '0', 10),
    ratingCount: rc,
    ratingAverage: Math.round(avg * 10) / 10,
  };
};

const getViewerIp = (req: ICustomRequest) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.length > 0) {
    return forwardedFor.split(',')[0].trim();
  }

  return req.socket.remoteAddress || null;
};

export const getAllUser = async (req: IRequestPagination & ICustomRequest, res: Response) => {
  const { self = 'false', email } = req.query;

  let where: any[] = [];
  if (self !== 'true') {
    where = [{ id: { [Op.ne]: req.user.id } }];
  }

  if (email) {
    where = [{ email }];
  }

  const { items, pagination: dataPagination } = await userService.getAll({ where }, req.pagination);

  bulkSetUserCache(items);

  const safeUsers = items?.map((user) => getSafeUser(user));
  return res.status(200).json({
    data: {
      items: safeUsers,
      pagination: dataPagination,
    },
  });
};

export const getUserById = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const data = await userService.getById(id as string);
  if (isEmpty(data)) throw new NotFoundError('User not found');

  await entityEngagementService.trackView('users', id as string, {
    userId: req.user.id,
    ip: getViewerIp(req),
    userAgent: req.headers['user-agent'] || null,
  });

  return res.status(200).json({ data: getSafeUser(data!) });
};

export const deleteUser = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const data = await userService.delete(id as string);
  return res.status(200).json({ data: getSafeUser(data!) });
};

export const updateUser = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const existingUser = await userService.getById(id as string);
  const updateBody = omit(req.body, ['password', 'email']);
  const data = await userService.update(id as string, updateBody);
  const safeUser = getSafeUser(data);

  if (hasMeaningfulChange(existingUser ? getSafeUser(existingUser) : null, safeUser)) {
    emitSocketEvent(PLATFORM_SOCKET_EVENTS.USER_UPDATE, { data: safeUser });
  }

  return res.status(200).json({ data: safeUser });
};

export const getUserByQuery = async (req: Request, res: Response) => {
  const { email, username } = req.query;

  let items: IBaseUser[] = [];
  let pagination = null;

  if (email) {
    const user = await userService.getUserByEmail(email as string);
    if (user) items = [user];
  } else if (username) {
    const usernameData = await userService.getUserByUsername(username as string);
    items = usernameData.items || [];
    pagination = usernameData.pagination;
  }

  const safeUsers = items.map((user) => getPublicUser(user));

  return res.status(200).json({
    data: {
      items: safeUsers,
      pagination,
    },
  });
};

export const getUserInterests = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const data = await userService.getUserInterests(id as string);
  return res.status(200).json({ data });
};

export const getUserSettings = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const user = await userService.getById(id as string);
  if (isEmpty(user)) throw new NotFoundError('User not found');

  const settings = await userSettingsService.ensureExists(id as string);
  return res.status(200).json({ data: settings });
};

export const updateUserSettings = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const user = await userService.getById(id as string);
  if (isEmpty(user)) throw new NotFoundError('User not found');

  const { notifications, privacy, onboarding, interests } = req.body;
  const settings = await userSettingsService.updateSettings(id as string, {
    notifications,
    privacy,
    onboarding,
    interests,
  });
  return res.status(200).json({ data: settings });
};

export const getUserImpact = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;

  const events = await Event.findAll({
    where: { createdBy: id },
    attributes: ['id', 'name', 'timings', 'createdAt'],
    order: [['createdAt', 'ASC']],
    limit: 50,
    raw: true,
  });

  if (!events.length) {
    return res.status(200).json({ data: { totalViews: 0, avgRating: 0, totalRatingCount: 0, events: [] } });
  }

  const breakdown = await Promise.all(
    events.map(async (event) => {
      const key = cacheKeys.engagementAggregate('events', event.id);
      const hash = (await analyticsRedis.hgetall(key)) as Record<string, string>;
      const stats =
        hash && Object.keys(hash).length > 0
          ? parseEngagementHash(hash)
          : { viewCount: 0, ratingCount: 0, ratingAverage: 0 };

      return {
        id: event.id,
        name: event.name,
        startTime: (event as any).timings?.start ?? event.createdAt,
        viewCount: stats.viewCount,
        ratingAverage: stats.ratingAverage,
        ratingCount: stats.ratingCount,
      };
    }),
  );

  const totalViews = breakdown.reduce((s, e) => s + e.viewCount, 0);
  const totalRatingCount = breakdown.reduce((s, e) => s + e.ratingCount, 0);
  const weightedSum = breakdown.reduce((s, e) => s + e.ratingAverage * e.ratingCount, 0);
  const avgRating = totalRatingCount > 0 ? Math.round((weightedSum / totalRatingCount) * 10) / 10 : 0;

  return res.status(200).json({ data: { totalViews, avgRating, totalRatingCount, events: breakdown } });
};
