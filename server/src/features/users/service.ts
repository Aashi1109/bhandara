import { EAddressEntityType } from '@/common/definitions/enums';
import type { IBaseUser, IMedia, IPaginationParams, PaginatedResult, ITag } from '@/common/definitions/types';
import AddressService from '@/features/addresses/service';
import { findAllWithPagination } from '@/common/utils/dbUtils';
import { validateUserCreate, validateUserUpdate } from './validation';
import { decryptUserRows, User } from './model';
import UserSettingsService from './settings.service';
import {
  bulkGetUserCache,
  bulkSetUserCache,
  deleteAllUserCache,
  deleteUserCache,
  getSafeUser,
  getUserCache,
  getUserCacheByEmail,
  getUserCacheByUsername,
  getUserInterestsCache,
  setUserCache,
  setUserCacheByEmail,
  setUserCacheByUsername,
  setUserInterestsCache,
} from './helpers';
import { BadRequestError, NotFoundError } from '@/common/exceptions';
import { hashForLookup, isEmpty } from '@/common/utils';
import TagService from '@/features/tags/service';
import MediaService from '@/features/media/service';
import type { FindOptions } from 'sequelize';

export interface IUserMini {
  id: string;
  name: string;
  avatarUrl: string | null;
}

export const toUserMini = (user: IBaseUser): IUserMini => {
  const media = user.media as IMedia | undefined;
  return {
    id: user.id,
    name: user.name,
    avatarUrl: media?.publicUrl ?? media?.url ?? null,
  };
};

class UserService {
  private readonly addressService: AddressService;
  private readonly getCache = getUserCache;
  private readonly setCache = setUserCache;
  private readonly deleteCache = deleteUserCache;

  private readonly tagService: TagService;
  private readonly mediaService: MediaService;
  private readonly settingsService: UserSettingsService;

  constructor() {
    this.addressService = new AddressService();
    this.tagService = new TagService();
    this.mediaService = new MediaService();
    this.settingsService = new UserSettingsService();
  }

  private decryptUsers<T extends Record<string, any>>(users: T[]) {
    return decryptUserRows(users);
  }

  private async hydrateUsers<T extends Pick<IBaseUser, 'id'> & Partial<IBaseUser>>(users: T[]): Promise<T[]> {
    if (users.length === 0) {
      return users;
    }

    const addressMap = await this.addressService.getByEntities(
      EAddressEntityType.User,
      users.map((user) => user.id),
    );

    return users.map((user) => ({
      ...user,
      address: this.addressService.toLocation(addressMap[user.id]),
    }));
  }

  async _getByIdNoCache(id: string): Promise<IBaseUser | null> {
    const res = (await User.findByPk(id, { raw: true })) as unknown as IBaseUser | null;
    if (!res) {
      return null;
    }

    const [hydrated] = await this.hydrateUsers(this.decryptUsers([res as IBaseUser]));
    return hydrated;
  }

  async getAll(
    options: FindOptions = {},
    pagination?: Partial<IPaginationParams>,
    select?: string,
  ): Promise<PaginatedResult<IBaseUser>> {
    const result = (await findAllWithPagination(
      User,
      options,
      pagination,
      select,
    )) as unknown as PaginatedResult<IBaseUser>;
    result.items = await this.hydrateUsers(this.decryptUsers(result.items as IBaseUser[]));
    return result;
  }

  async create(data: Partial<IBaseUser>): Promise<IBaseUser | null> {
    const res = await validateUserCreate(data, async (d) => {
      const { address, __sid, ...rest } = d as IBaseUser;
      const row = await User.sequelize!.transaction(async (transaction) => {
        const created = await User.create(
          {
            ...rest,
            __sid,
            mediaId: d.mediaId as string,
          } as any,
          { transaction },
        );
        await Promise.all([
          this.addressService.replaceAddress(EAddressEntityType.User, created.id, address, transaction),
          this.settingsService.updateSettings(created.id, {}, transaction),
        ]);
        return created;
      });
      return (await this._getByIdNoCache(row.id)) as IBaseUser;
    });
    const created = res as IBaseUser;
    if (created) {
      await this.setCache(created.id, created);
    }
    return res;
  }

  async setSupabaseSid(id: string, sid: string): Promise<IBaseUser | null> {
    const existing = await this._getByIdNoCache(id);
    if (!existing) {
      return null;
    }

    const row = await User.findByPk(id);
    if (!row) {
      return null;
    }

    await row.update({ __sid: sid } as Partial<IBaseUser>);
    await deleteAllUserCache(id, existing);
    return this._getByIdNoCache(id);
  }

  async update(id: string, data: Partial<IBaseUser>) {
    const updated = await validateUserUpdate(data, async (validData) => {
      const userData = await this._getByIdNoCache(id);

      if (!userData) throw new NotFoundError('User not found');

      const { username, address, ...rest } = validData;

      const newMeta = { ...userData.meta };

      const isUsernameChanged = username && username !== userData.username;
      if (isUsernameChanged) {
        const usernameData = await this.getUserByUsername(username);
        if (!isEmpty(usernameData.items)) throw new BadRequestError('Username already exists');
      }

      await User.sequelize!.transaction(async (transaction) => {
        const row = await User.findByPk(id, { transaction });
        if (!row) throw new NotFoundError('User not found');
        await row.update(
          {
            ...rest,
            meta: newMeta,
            username: isUsernameChanged ? username : row.username,
            mediaId: rest.mediaId ?? row.mediaId,
          } as Partial<IBaseUser>,
          { transaction },
        );

        if (address !== undefined) {
          await this.addressService.replaceAddress(EAddressEntityType.User, id, address, transaction);
        }
      });

      const updatedUser = (await this._getByIdNoCache(id)) as IBaseUser;
      if (rest.mediaId) {
        updatedUser.media = (await this.mediaService.getById(rest.mediaId as string)) ?? undefined;
      }

      await this.deleteCache(id);
      return updatedUser;
    });
    return updated;
  }

  async getById(id: string): Promise<IBaseUser | null> {
    let _user = await this.getCache(id);
    if (!_user) _user = await this._getByIdNoCache(id);
    if (!_user) return null;
    if (_user.mediaId) {
      const media = await this.mediaService.getById(_user.mediaId as string);
      (_user as IBaseUser).media = media ?? undefined;
    }

    await this.setCache(id, _user as IBaseUser);
    return _user;
  }

  async getUserByEmail(email: string) {
    const cached = await getUserCacheByEmail(email);
    if (cached) return cached;
    const data = (await findAllWithPagination(
      User,
      { where: { emailLookupHash: hashForLookup(email) } },
      { limit: 1 },
    )) as unknown as PaginatedResult<IBaseUser>;
    if (data.items.length === 0) return null;
    const [user] = await this.hydrateUsers(this.decryptUsers(data.items as IBaseUser[]));
    if (user.mediaId) {
      const media = await this.mediaService.getById(user.mediaId as string);
      user.media = media as IMedia;
    }
    await setUserCacheByEmail(email, user);
    return user;
  }

  async getUserByUsername(username: string): Promise<PaginatedResult<IBaseUser>> {
    const cached = await getUserCacheByUsername(username);
    if (cached)
      return {
        items: [cached],
        pagination: null,
      } as unknown as PaginatedResult<IBaseUser>;
    const data = (await findAllWithPagination(
      User,
      { where: { username } },
      { limit: 1 },
    )) as unknown as PaginatedResult<IBaseUser>;
    if (!isEmpty(data.items)) {
      const [user] = await this.hydrateUsers(this.decryptUsers(data.items as IBaseUser[]));
      data.items = [user] as typeof data.items;
      await setUserCacheByUsername(username, user);
    }
    return data;
  }

  async delete(id: string): Promise<IBaseUser | null> {
    const existing = await this._getByIdNoCache(id);
    if (!existing) return null;

    const row = await User.findByPk(id);
    if (!row) return null;
    await User.sequelize!.transaction(async (transaction) => {
      await this.addressService.replaceAddress(EAddressEntityType.User, id, null, transaction);
      await row.destroy({ transaction });
    });
    await deleteAllUserCache(id, existing);
    return existing;
  }

  async updateMeta(id: string, metaUpdate: Record<string, any>): Promise<void> {
    const row = await User.findByPk(id);
    if (!row) return;
    const currentMeta = (row.meta as Record<string, any>) || {};
    await row.update({ meta: { ...currentMeta, ...metaUpdate } });
    await deleteUserCache(id);
  }

  async getUserMini(id: string): Promise<IUserMini | null> {
    const row = (await User.findByPk(id, {
      attributes: ['id', 'name', 'mediaId'],
      raw: true,
    })) as unknown as Pick<IBaseUser, 'id' | 'name' | 'mediaId'> | null;
    if (!row) return null;

    let avatarUrl: string | null = null;
    if (row.mediaId) {
      const media = await this.mediaService.getById(row.mediaId as string);
      if (media) {
        avatarUrl = media.publicUrl ?? media.url ?? null;
      }
    }

    return { id: row.id, name: row.name, avatarUrl };
  }

  async getUserInterests(id: string) {
    const cached = await getUserInterestsCache(id);
    if (cached) return cached;

    const settings = await this.settingsService.ensureExists(id);
    const interests = settings.interests;

    if (isEmpty(interests)) return [];

    const tags = await this.tagService.getAll({ where: { id: interests } });
    await setUserInterestsCache(id, tags.items as ITag[]);
    return tags.items;
  }

  async getUserProfiles(
    ids: string[],
    transformerFunction?: (user: IBaseUser) => Record<string, any>,
  ): Promise<Record<string, IBaseUser>> {
    let fetchedUsers = await bulkGetUserCache(ids);

    if (fetchedUsers.length !== ids.length) {
      // find the users that are not in the cache
      const usersToFetch = new Set(ids);
      fetchedUsers.forEach((user) => {
        usersToFetch.delete(user.id);
      });

      const toFetchIds = Array.from(usersToFetch);

      const { items: users } = await this.getAll({ where: { id: toFetchIds } }, { limit: toFetchIds.length });
      await bulkSetUserCache(users);
      fetchedUsers = [...fetchedUsers, ...users];
    }

    const mediaIds = fetchedUsers.reduce((acc, user) => {
      if (user.mediaId) acc.push(user.mediaId as string);
      return acc;
    }, [] as string[]);

    const mediaData = await this.mediaService.getMediaByIds(mediaIds);

    const safeUsers = fetchedUsers.reduce(
      (acc, user) => {
        if (transformerFunction) {
          acc[user.id] = transformerFunction({
            ...user,
            media: mediaData[user.mediaId as string],
          }) as IBaseUser;
        } else {
          acc[user.id] = getSafeUser(user);
        }

        return acc;
      },
      {} as Record<string, IBaseUser>,
    );

    return safeUsers;
  }

  /**
   * Retrieves user profiles by their IDs, with caching support and media population
   * @param {Array<T>} data - Array of items to fetch user profiles for
   * @param {keyof T} searchKey - Key to search for user IDs in the data
   * @param {keyof T} [populateKey] - Optional key to populate the user profile in the data
   * @returns {Promise<Array<T>>} Array of items with user profiles populated
   */
  async getAndPopulateUserProfiles<T extends Record<string, any>>({
    data,
    searchKey,
    populateKey,
    transformerFunction,
  }: {
    data: Array<T>;
    searchKey: keyof T;
    populateKey?: keyof T;
    transformerFunction?: (user: IBaseUser) => Record<string, any>;
  }): Promise<Array<T>> {
    if (isEmpty(data)) return data;
    const ids = data.map((item) => item[searchKey]);
    const users = await this.getUserProfiles(ids, transformerFunction);

    return data.map((item) => {
      const user = users[item[searchKey]];
      if (!user) return item;
      return {
        ...item,
        [populateKey ?? searchKey]: users[item[searchKey]],
      };
    });
  }
}

export default UserService;
