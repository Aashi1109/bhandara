import type { IRequestPagination, ICustomRequest, IBaseUser } from '@/definitions/types';
import { bulkSetUserCache, getPublicUser, getSafeUser } from './helpers';
import UserService from './service';
import type { Request, Response } from 'express';
import { isEmpty, omit } from '@/utils';
import { NotFoundError } from '@/exceptions';
import { Op } from 'sequelize';
import EntityEngagementService from '@/features/engagement/service';

const userService = new UserService();
const entityEngagementService = new EntityEngagementService();

const getViewerIp = (req: ICustomRequest) => {
  const forwardedFor = req.headers['x-forwarded-for'];
  if (typeof forwardedFor === 'string' && forwardedFor.length > 0) {
    return forwardedFor.split(',')[0].trim();
  }

  return req.socket.remoteAddress || null;
};

export const getAllUser = async (req: IRequestPagination & ICustomRequest, res: Response) => {
  const { self = 'false', email } = req.query;

  let where = [];
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

  return res.status(200).json({ data: getSafeUser(data) });
};

export const deleteUser = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const data = await userService.delete(id as string);
  return res.status(200).json({ data: getSafeUser(data) });
};

export const updateUser = async (req: ICustomRequest, res: Response) => {
  const { id } = req.params;
  const updateBody = omit(req.body, ['password', 'email']);
  const data = await userService.update(id as string, updateBody);
  return res.status(200).json({ data: getSafeUser(data) });
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
