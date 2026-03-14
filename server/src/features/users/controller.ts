import type { IRequestPagination, ICustomRequest, IBaseUser } from '@/definitions/types';
import { bulkSetUserCache, getSafeUser } from './helpers';
import UserService from './service';
import type { Response } from 'express';
import { isEmpty, omit } from '@/utils';
import { NotFoundError } from '@/exceptions';
import { Op } from 'sequelize';

const userService = new UserService();

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

export const getUserByQuery = async (req: ICustomRequest, res: Response) => {
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

  const safeUsers = items.map((user) => getSafeUser(user));

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
