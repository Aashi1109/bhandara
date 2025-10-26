import {
  IBaseUser,
  IMedia,
  IPaginationParams,
  ITag,
} from "@/definitions/types";
import { findAllWithPagination, PaginatedResult } from "@/utils/dbUtils";
import { validateUserCreate, validateUserUpdate } from "./validation";
import { User } from "./model";
import {
  bulkGetUserCache,
  bulkSetUserCache,
  deleteAllUserCache,
  deleteUserCache,
  deleteUserInterestsCache,
  getSafeUser,
  getUserCache,
  getUserCacheByEmail,
  getUserCacheByUsername,
  getUserInterestsCache,
  setUserCache,
  setUserCacheByEmail,
  setUserCacheByUsername,
  setUserInterestsCache,
} from "./helpers";
import { BadRequestError, NotFoundError } from "@/exceptions";
import { isEmpty } from "@/utils";
import TagService from "@/features/tags/service";
import MediaService from "@/features/media/service";
import { FindOptions } from "sequelize";

class UserService {
  private readonly getCache = getUserCache;
  private readonly setCache = setUserCache;
  private readonly deleteCache = deleteUserCache;

  private readonly tagService: TagService;
  private readonly mediaService: MediaService;

  constructor() {
    this.tagService = new TagService();
    this.mediaService = new MediaService();
  }

  async _getByIdNoCache(id: string): Promise<IBaseUser | null> {
    const res = await User.findByPk(id, { raw: true });
    return res as IBaseUser | null;
  }

  async getAll(
    options: FindOptions = {},
    pagination?: Partial<IPaginationParams>,
    select?: string
  ) {
    return findAllWithPagination(User, options, pagination, select);
  }

  async create(data: Partial<IBaseUser>): Promise<IBaseUser | null> {
    const res = await validateUserCreate(data, async (d) => {
      const row = await User.create({
        ...d,
        mediaId: d.mediaId as string,
      } as Partial<IBaseUser>);
      return row.toJSON() as IBaseUser;
    });
    const created = res as IBaseUser;
    if (created) {
      await this.setCache(created.id, created);
    }
    return res;
  }

  async update(
    id: string,
    data: Partial<
      IBaseUser & {
        interests: { added: string[]; deleted: string[] };
        hasOnboarded: boolean;
      }
    >
  ) {
    const updated = await validateUserUpdate(data, async (validData) => {
      const userData = await this._getByIdNoCache(id);

      if (!userData) throw new NotFoundError("User not found");

      const { interests, hasOnboarded, username, ...rest } = validData;

      const newInterests = [...(interests?.added || [])] as string[];
      const deletedInterests = [...(interests?.deleted || [])] as string[];

      const newInterestsSet = new Set(newInterests);
      const deletedInterestsSet = new Set(deletedInterests);

      const previousInterests = new Set([...(userData.meta?.interests || [])]);

      deletedInterestsSet.forEach((interest) => {
        newInterestsSet.delete(interest);
        previousInterests.delete(interest);
      });

      const newMeta = {
        ...userData.meta,
        hasOnboarded: hasOnboarded ?? userData.meta?.hasOnboarded,
        interests: [
          ...Array.from(newInterestsSet),
          ...Array.from(previousInterests),
        ],
      };

      const hasInterestsChanged =
        newInterests.length > 0 || deletedInterests.length > 0;

      if (hasInterestsChanged) {
        await deleteUserInterestsCache(id);
      }

      const isUsernameChanged = username && username !== userData.username;
      if (isUsernameChanged) {
        const usernameData = await this.getUserByUsername(username);
        if (!isEmpty(usernameData.items))
          throw new BadRequestError("Username already exists");
      }

      const row = await User.findByPk(id);
      if (!row) throw new NotFoundError("User not found");
      await row.update({
        ...rest,
        meta: newMeta,
        username,
        mediaId: rest.mediaId as string,
      } as Partial<IBaseUser>);

      let updatedUser = row.toJSON() as IBaseUser;
      if (rest.mediaId) {
        updatedUser.media = await this.mediaService.getById(
          rest.mediaId as string
        );
      }

      await this.deleteCache(id);
      return updatedUser;
    });
    return updated;
  }

  async getById(id: string): Promise<IBaseUser | null> {
    let _user = await this.getCache(id);
    if (!_user)
      _user = (await User.findByPk(id, { raw: true })) as IBaseUser | null;
    if (!_user) return null;
    if (_user.mediaId) {
      const media = await this.mediaService.getById(_user.mediaId as string);
      (_user as IBaseUser).media = media as IMedia;
    }

    await this.setCache(id, _user as IBaseUser);
    return _user;
  }

  async getUserByEmail(email: string) {
    const cached = await getUserCacheByEmail(email);
    if (cached) return cached;
    const data = await findAllWithPagination(
      User,
      { where: { email } },
      { limit: 1 }
    );
    if (data.items.length === 0) return null;
    const user = data.items[0];
    if (user.mediaId) {
      const media = await this.mediaService.getById(user.mediaId as string);
      user.media = media as IMedia;
    }
    await setUserCacheByEmail(email, user);
    return user;
  }

  async getUserByUsername(
    username: string
  ): Promise<PaginatedResult<IBaseUser>> {
    const cached = await getUserCacheByUsername(username);
    if (cached)
      return {
        items: [cached],
        pagination: null,
      } as PaginatedResult<IBaseUser>;
    const data = await findAllWithPagination(
      User,
      { where: { username } },
      { limit: 1 }
    );
    if (!isEmpty(data.items)) {
      await setUserCacheByUsername(username, data.items[0]);
    }
    return data;
  }

  async delete(id: string): Promise<IBaseUser | null> {
    const row = await User.findByPk(id);
    if (!row) return null;
    await row.destroy();
    await deleteAllUserCache(id);
    return row.toJSON() as IBaseUser;
  }

  async getUserInterests(id: string) {
    const cached = await getUserInterestsCache(id);
    if (cached) return cached;
    const user = await this.getById(id);
    if (!user) throw new NotFoundError("User not found");

    const { interests } = user.meta;

    if (isEmpty(interests)) return [];

    const tags = await this.tagService.getAll({ where: { id: interests } });
    await setUserInterestsCache(id, tags.items as ITag[]);
    return tags.items;
  }

  async getUserProfiles(
    ids: string[],
    transformerFunction?: (user: IBaseUser) => Record<string, any>
  ): Promise<Record<string, IBaseUser>> {
    let fetchedUsers = await bulkGetUserCache(ids);

    if (fetchedUsers.length !== ids.length) {
      // find the users that are not in the cache
      const usersToFetch = new Set(ids);
      fetchedUsers.forEach((user) => {
        usersToFetch.delete(user.id);
      });

      const toFetchIds = Array.from(usersToFetch);

      const { items: users } = await this.getAll(
        { where: { id: toFetchIds } },
        { limit: toFetchIds.length }
      );
      await bulkSetUserCache(users);
      fetchedUsers = [...fetchedUsers, ...users];
    }

    const mediaIds = fetchedUsers.reduce((acc, user) => {
      if (user.mediaId) acc.push(user.mediaId as string);
      return acc;
    }, [] as string[]);

    const mediaData = await this.mediaService.getMediaByIds(mediaIds);

    const safeUsers = fetchedUsers.reduce((acc, user) => {
      acc[user.id] = getSafeUser(
        transformerFunction
          ? (transformerFunction({
              ...user,
              media: mediaData[user.mediaId as string],
            }) as IBaseUser)
          : user
      );

      return acc;
    }, {} as Record<string, IBaseUser>);

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
