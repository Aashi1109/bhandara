import {
  IMessage,
  IMessageContent,
  IPaginationParams,
} from "@/definitions/types";
import { findAllWithPagination } from "@/utils/dbUtils";
import { validateMessageCreate, validateMessageUpdate } from "./validation";
import { Message } from "./model";
import MediaService from "@/features/media/service";
import { isEmpty } from "@/utils";
import UserService from "@/features/users/service";
import { BadRequestError } from "@/exceptions";
import ReactionService from "@/features/reactions/service";

// Note: Thread data is intentionally not populated here to avoid
// circular dependencies between services. Controllers should fetch
// thread details separately when needed.
class MessageService {
  private readonly mediaService: MediaService;
  private readonly userService: UserService;
  private readonly reactionService: ReactionService;

  private readonly populateFields = ["user", "reactions", "media"];

  constructor() {
    this.mediaService = new MediaService();
    this.userService = new UserService();
    this.reactionService = new ReactionService();
  }

  private async populateMessage(message: IMessage, fields: string[]) {
    const promises: Record<string, Promise<any>> = {};

    fields.forEach((field) => {
      switch (field) {
        case "user":
          promises.user = this.userService.getById(message.userId);
          break;
        case "reactions":
          promises.reactions = this.reactionService.getReactions(
            `messages/${message.id}`
          );
          break;
        case "media":
          if ("media" in message.content) {
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
      resolved[key] = r.status === "fulfilled" ? r.value : null;
    });

    if (fields.includes("user")) message.user = resolved.user?.data || null;
    if (fields.includes("reactions"))
      message.reactions = resolved.reactions?.data || [];
    if (fields.includes("media") && resolved.media) {
      message.content = {
        ...message.content,
        media: (message.content.media as string[]).map(
          (id) => resolved.media[id]
        ),
      } as IMessageContent;
    }

    return message;
  }

  async getAll(
    where: Record<string, any> = {},
    pagination: Partial<IPaginationParams> = {}
  ) {
    const { items: parentItems, pagination: parentPagination } =
      await findAllWithPagination(
        Message,
        { ...where, parentId: null },
        pagination
      );

    // Step 2: Fetch total count of parent threads for pagination metadata
    const childMessagesPromises = (parentItems || [])?.map(async (m) => {
      const mediaIds = [...((m.content as any)?.media || [])];

      const mediaData = await this.mediaService.getMediaByIds(mediaIds);

      if ("media" in m.content) {
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

    const parentMessageWithPopulatedUsers =
      await this.userService.getAndPopulateUserProfiles({
        data: parentItems || [],
        searchKey: "userId",
        populateKey: "user",
      });

    // Using the same index ensures each child is matched with its correct parent
    const messagesWithChildren = parentMessageWithPopulatedUsers?.map(
      (parent, index) => ({
        ...parent,
        children: childMessages[index].items,
      })
    );

    return {
      items: messagesWithChildren || [],
      pagination: parentPagination,
    };
  }

  async getChildren(
    threadId: string,
    parentId: string,
    pagination: Partial<IPaginationParams>
  ) {
    const data = await findAllWithPagination(
      Message,
      { threadId, parentId },
      pagination
    );
    if (!isEmpty(data.items)) {
      const mediaIds = data.items
        .map((m) => {
          if ("media" in m.content) {
            return (m.content as any)?.media;
          }
          return [];
        })
        .flat();

      const mediaData = await this.mediaService.getMediaByIds(mediaIds);

      data.items.forEach((m) => {
        if ("media" in m.content) {
          m.content.media = (m.content.media as string[]).map(
            (media) => mediaData[media]
          );
        }
      });

      const userPopulatedMessages =
        await this.userService.getAndPopulateUserProfiles({
          data: data.items,
          searchKey: "userId",
          populateKey: "user",
        });

      const reactionPromises = userPopulatedMessages.map((msg) =>
        this.reactionService.getReactions(`messages/${msg.id}`)
      );
      const reactionResults = await Promise.all(reactionPromises);
      userPopulatedMessages.forEach((msg, idx) => {
        msg.reactions = reactionResults[idx];
      });

      return { items: userPopulatedMessages, pagination: data.pagination };
    }
    return data;
  }

  async create<U extends Partial<Omit<IMessage, "id" | "updatedAt">>>(
    data: U,
    populate?: boolean | string[]
  ) {
    const created = await validateMessageCreate(data, async (validData) => {
      if (validData.parentId) {
        const parent = await this.getById(validData.parentId);
        if (!parent) throw new BadRequestError("Parent message not found");
        if (parent.parentId)
          throw new BadRequestError(
            "Nested messages beyond one level are not allowed"
          );
      }
      const row = await Message.create(validData as any);
      return row.toJSON() as any;
    });
    let msg =
      (created as any)?.dataValues ||
      (created as any)?.[0]?.dataValues ||
      created;
    if (populate && msg) {
      msg = await this.getById(msg.id, populate);
    }
    return msg as IMessage;
  }

  async update<U extends Partial<IMessage>>(
    id: string,
    data: U,
    populate?: boolean | string[]
  ) {
    const updated = await validateMessageUpdate(data, async (validData) => {
      if (validData.parentId) {
        const parent = await this.getById(validData.parentId);
        if (!parent) throw new BadRequestError("Parent message not found");
        if (parent.parentId)
          throw new BadRequestError(
            "Nested messages beyond one level are not allowed"
          );
      }
      const [count, rows] = await Message.update(validData as any, {
        where: { id },
        returning: true,
      });
      if (count === 0) throw new Error("Message not found");
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
        populate === true
          ? this.populateFields
          : this.populateFields.filter((f) =>
              (populate as string[]).includes(f)
            );
      const populated = await this.populateMessage(data as IMessage, fields);
      return populated;
    }
    return data as any;
  }

  async delete(id: string) {
    const row = await Message.findByPk(id);
    if (!row) return null;
    await row.destroy();
    return row.toJSON() as any;
  }
}

export default MessageService;
