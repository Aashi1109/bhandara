import type { IMessage, IMessageContent, IPaginationParams } from '@/common/definitions/types';
import { findAllWithPagination } from '@/common/utils/dbUtils';
import { validateMessageCreate, validateMessageUpdate } from './validation';
import { Message } from './model';
import MediaService from '@/features/media/service';
import { isEmpty } from '@/common/utils';
import UserService, { toUserMini } from '@/features/users/service';
import { BadRequestError, NotFoundError } from '@/common/exceptions';
import ReactionService from '@/features/reactions/service';
import { Op } from 'sequelize';
import EntityStatsService from '@/features/stats/service';

// Note: Thread data is intentionally not populated here to avoid
// circular dependencies between services. Controllers should fetch
// thread details separately when needed.
class MessageService {
  private readonly mediaService: MediaService;
  private readonly userService: UserService;
  private readonly reactionService: ReactionService;
  private readonly entityStatsService: EntityStatsService;

  private readonly populateFields = ['user', 'reactions', 'media'];

  constructor() {
    this.mediaService = new MediaService();
    this.userService = new UserService();
    this.reactionService = new ReactionService();
    this.entityStatsService = new EntityStatsService();
  }

  private async assertValidParent(parentId: string): Promise<void> {
    const parent = (await Message.findByPk(parentId, {
      attributes: ['id', 'parentId'],
      raw: true,
    })) as IMessage | null;
    if (!parent) throw new BadRequestError('Parent message not found');
    if (parent.parentId) throw new BadRequestError('Nested messages beyond one level are not allowed');
  }

  private normalizeMessageContent(content: IMessage['content'] | string | undefined): IMessageContent {
    if (typeof content === 'string') {
      return { text: content };
    }

    if (!content || typeof content !== 'object') {
      return { text: '' };
    }

    const rawContent = content as Record<string, unknown>;
    const rawText = rawContent['text'];
    const normalizedText = typeof rawText === 'string' ? rawText : rawText === null ? '' : String(rawText);
    const normalizedMedia = Array.isArray(rawContent['media'])
      ? rawContent['media']
          .map((item) => {
            if (typeof item === 'string') {
              return item;
            }
            if (item && typeof item === 'object') {
              const mediaObject = item as Record<string, unknown>;
              if (typeof mediaObject['id'] === 'string') {
                return mediaObject['id'];
              }
              if (typeof mediaObject['mediaId'] === 'string') {
                return mediaObject['mediaId'];
              }
            }
            return null;
          })
          .filter((item): item is string => typeof item === 'string' && item.length > 0)
      : undefined;

    if ((normalizedMedia?.length ?? 0) > 0) {
      return normalizedText.length > 0
        ? {
            text: normalizedText,
            media: normalizedMedia,
          }
        : {
            media: normalizedMedia,
          };
    }

    return {
      text: normalizedText,
    };
  }

  private async populateMessage(message: IMessage, fields: string[]) {
    const promises: Record<string, Promise<any>> = {};

    fields.forEach((field) => {
      switch (field) {
        case 'user':
          promises.user = this.userService.getById(message.userId);
          break;
        case 'reactions':
          promises.reactions = this.reactionService.getReactions(`messages/${message.id}`);
          break;
        case 'media':
          if ('media' in message.content) {
            const ids = (message.content.media as string[]) || [];
            promises.media = this.mediaService.getMediaByIds(ids);
          }
          break;
      }
    });

    const results = await Promise.allSettled(Object.values(promises));
    const resolved: Record<string, any> = {};
    Object.keys(promises).forEach((key, idx) => {
      const r = results[idx];
      resolved[key] = r.status === 'fulfilled' ? r.value : null;
    });

    if (fields.includes('user')) message.user = resolved.user || null;
    if (fields.includes('reactions')) message.reactions = resolved.reactions || [];
    if (fields.includes('media') && resolved.media) {
      message.content = {
        ...message.content,
        media: (message.content.media as string[]).map((id) => resolved.media[id]),
      } as IMessageContent;
    }

    return message;
  }

  async getAll(where: Record<string, any> = {}, pagination: Partial<IPaginationParams> = {}) {
    const { items: parentItems, pagination: parentPagination } = await findAllWithPagination(
      Message,
      { where: { ...where, parentId: { [Op.eq]: null } } },
      pagination,
    );

    // Step 2: Fetch total count of parent threads for pagination metadata
    const childMessagesPromises = (parentItems || [])?.map(async (m) => {
      const mediaIds = [...((m.content as any)?.media || [])];

      const mediaData = await this.mediaService.getMediaByIds(mediaIds);

      if ('media' in m.content) {
        m.content.media = (m.content.media as string[]).map((media) => {
          return mediaData[media];
        });
      }

      const [children, reactions] = await Promise.all([
        this.getChildren(m.threadId, m.id, { limit: 1 }),
        this.reactionService.getReactions(`messages/${m.id}`),
      ]);
      m.reactions = reactions;
      return children;
    });

    const childMessages = await Promise.all(childMessagesPromises);

    const parentMessageWithPopulatedUsers = await this.userService.getAndPopulateUserProfiles({
      data: parentItems || [],
      searchKey: 'userId',
      populateKey: 'user',
      transformerFunction: toUserMini,
    });

    // Using the same index ensures each child is matched with its correct parent
    const messagesWithChildren = parentMessageWithPopulatedUsers?.map((parent, index) => ({
      ...parent,
      children: childMessages[index].items,
    }));

    await this.entityStatsService.hydrateMessages(messagesWithChildren || []);

    return {
      items: messagesWithChildren || [],
      pagination: parentPagination,
    };
  }

  async getChildren(threadId: string, parentId: string, pagination: Partial<IPaginationParams>) {
    const data = await findAllWithPagination(Message, { where: { threadId, parentId } }, pagination);
    if (!isEmpty(data.items)) {
      const mediaIds = data.items
        .map((m) => {
          if ('media' in m.content) {
            return (m.content as any)?.media;
          }
          return [];
        })
        .flat();

      const mediaData = await this.mediaService.getMediaByIds(mediaIds);

      data.items.forEach((m) => {
        if ('media' in m.content) {
          m.content.media = (m.content.media as string[]).map((media) => mediaData[media]);
        }
      });

      const userPopulatedMessages = await this.userService.getAndPopulateUserProfiles({
        data: data.items,
        searchKey: 'userId',
        populateKey: 'user',
        transformerFunction: toUserMini,
      });

      const contentIds = userPopulatedMessages.map((msg) => `messages/${msg.id}`);
      const reactionsMap = await this.reactionService.getReactionsBatch(contentIds);
      userPopulatedMessages.forEach((msg) => {
        msg.reactions = reactionsMap[`messages/${msg.id}`] ?? [];
      });

      await this.entityStatsService.hydrateMessages(userPopulatedMessages);
      return { items: userPopulatedMessages, pagination: data.pagination };
    }
    return data;
  }

  async create<U extends Partial<Omit<IMessage, 'id' | 'updatedAt'>>>(data: U, populate?: boolean | string[]) {
    const normalizedData = {
      ...data,
      content: this.normalizeMessageContent(data.content as IMessage['content'] | string | undefined),
    };

    const created = await validateMessageCreate(normalizedData, async (validData) => {
      if (validData.parentId) {
        await this.assertValidParent(validData.parentId);
      }
      const row = await Message.create(validData as any);
      return row.toJSON() as any;
    });
    let msg = (created as any)?.dataValues || (created as any)?.[0]?.dataValues || created;
    if (populate && msg) {
      msg = await this.getById(msg.id, populate);
    } else if (msg) {
      await Promise.all([
        this.entityStatsService.incrementThreadStat(msg.threadId, 'messageCount', 1),
        msg.parentId ? this.entityStatsService.incrementMessageStat(msg.parentId, 'replyCount', 1) : Promise.resolve(),
      ]);
    }
    if (msg && populate) {
      await Promise.all([
        this.entityStatsService.incrementThreadStat(msg.threadId, 'messageCount', 1),
        msg.parentId ? this.entityStatsService.incrementMessageStat(msg.parentId, 'replyCount', 1) : Promise.resolve(),
      ]);
    }
    return msg as IMessage;
  }

  async update<U extends Partial<IMessage>>(id: string, data: U, populate?: boolean | string[]) {
    const normalizedData =
      data.content === undefined
        ? data
        : {
            ...data,
            content: this.normalizeMessageContent(data.content as IMessage['content'] | string | undefined),
          };

    const updated = await validateMessageUpdate(normalizedData, async (validData) => {
      if (validData.parentId) {
        await this.assertValidParent(validData.parentId);
      }
      const [count, rows] = await Message.update(validData as any, {
        where: { id },
        returning: true,
      });
      if (count === 0) throw new NotFoundError('Message not found');
      return rows[0];
    });
    let msg = (updated as any)?.[0] ?? updated;
    if (populate && msg) {
      msg = await this.getById(id, populate);
    }
    return msg;
  }

  async getById(id: string, populate?: boolean | string[]) {
    const data = (await Message.findByPk(id, { raw: true })) as IMessage | null;
    if (populate && data) {
      const fields =
        populate === true ? this.populateFields : this.populateFields.filter((f) => (populate as string[]).includes(f));
      const populated = await this.populateMessage(data as IMessage, fields);
      return this.entityStatsService.hydrateMessage(populated);
    }
    return data ? this.entityStatsService.hydrateMessage(data as IMessage) : (data as any);
  }

  async getByIds(ids: string[]): Promise<IMessage[]> {
    if (!ids.length) return [];
    return (await Message.findAll({ where: { id: ids }, raw: true })) as IMessage[];
  }

  async getMessagesByThreadIds(
    threadIds: string[],
    pagination: Partial<IPaginationParams> = {},
  ): Promise<Record<string, IMessage[]>> {
    if (!threadIds.length) return {};
    const { limit = 1 } = pagination;

    const rows = (await Message.findAll({
      where: { threadId: threadIds, parentId: { [Op.eq]: null } },
      order: [['createdAt', 'DESC']],
      raw: true,
    })) as IMessage[];

    const grouped: Record<string, IMessage[]> = {};
    threadIds.forEach((id) => {
      grouped[id] = [];
    });
    rows.forEach((msg) => {
      const bucket = grouped[msg.threadId];
      if (bucket && bucket.length < limit) {
        bucket.push(msg);
      }
    });

    return grouped;
  }

  async delete(id: string) {
    const row = await Message.findByPk(id);
    if (!row) return null;
    await row.destroy();
    const deletedMessage = row.toJSON() as IMessage;
    await Promise.all([
      this.entityStatsService.incrementThreadStat(deletedMessage.threadId, 'messageCount', -1),
      deletedMessage.parentId
        ? this.entityStatsService.incrementMessageStat(deletedMessage.parentId, 'replyCount', -1)
        : Promise.resolve(),
    ]);
    return deletedMessage as any;
  }
}

export default MessageService;
