import { validateThreadCreate, validateThreadUpdate } from "./validation";
import { Thread } from "./model";

import { IPaginationParams, IMessage } from "@/definitions/types";
import { findAllWithPagination } from "@utils/dbUtils";
import { getThreadCache, setThreadCache, deleteThreadCache, isThreadLocked, canUserModifyLockedThread, lockThread, unlockThread } from "./helpers";
import { IBaseThread } from "@definitions/types";
import { BadRequestError, ForbiddenError } from "@exceptions";

import MessageService from "@features/messages/service";

class ThreadsService {
  private readonly getCache = getThreadCache;
  private readonly setCache = setThreadCache;
  private readonly deleteCache = deleteThreadCache;
  private readonly messageService: MessageService;

  private readonly populateFields = ["messages"];

  constructor() {
    this.messageService = new MessageService();
  }

  private async populateThread(thread: IBaseThread, fields: string[]) {
    const promises: Record<string, Promise<any>> = {};

    fields.forEach((field) => {
      switch (field) {
        case "messages":
          promises.messages = this.messageService.getAll(
            { threadId: thread.id },
            { limit: 10 }
          );
          break;
      }
    });

    const results = await Promise.allSettled(Object.values(promises));
    const resolved: Record<string, any> = {};
    Object.keys(promises).forEach((key, idx) => {
      const r = results[idx];
      resolved[key] = r.status === "fulfilled" ? r.value : null;
    });

    if (fields.includes("messages")) {
      thread.messages = resolved.messages?.items;
    }

    return thread;
  }

  async _getByIdNoCache(id: string) {
    const res = await Thread.findByPk(id, { raw: true });
    return res as any;
  }

  async create<U extends Partial<Omit<IBaseThread, "id" | "updatedAt">>>(
    data: U,
    populate?: boolean | string[]
  ) {
    const created = await validateThreadCreate(data, async (validData) => {
      if (validData.parentId) {
        const parent = await this.getById(validData.parentId);
        if (!parent) throw new BadRequestError("Parent thread not found");
        if (parent.parentId)
          throw new BadRequestError(
            "Nested threads beyond one level are not allowed"
          );
      }
      const row = await Thread.create(validData as any);
      return row.toJSON() as any;
    });
    let thread =
      (created as any)?.dataValues ||
      (created as any)?.[0]?.dataValues ||
      created;
    if (thread) {
      await this.setCache((thread as any).id, thread as any);
    }
    if (populate && thread) {
      thread = await this.getById(thread.id);
    }
    return thread as IBaseThread;
  }

  async getById(id: string) {
    const cached = await this.getCache(id);
    if (cached) return cached as any;

    const res = await Thread.findByPk(id, { raw: true });
    if (res) await this.setCache(id, res as any);
    return res as any;
  }

  async update<U extends Partial<IBaseThread>>(
    id: string,
    data: U,
    populate?: boolean | string[]
  ) {
    const updated = await validateThreadUpdate(data, async (validData) => {
      if (validData.parentId) {
        const parent = await this.getById(validData.parentId);
        if (!parent) throw new BadRequestError("Parent thread not found");
        if (parent.parentId)
          throw new BadRequestError(
            "Nested threads beyond one level are not allowed"
          );
      }
      const row = await Thread.findByPk(id);
      if (!row) throw new Error("Thread not found");
      await row.update(validData as any);
      return row.toJSON() as any;
    });
    await this.deleteCache(id);
    let thread = (updated as any)?.[0] ?? updated;
    if (populate && thread) {
      thread = await this.getById(id);
    }
    return thread as any;
  }

  async getAll(
    where: Record<string, any> = {},
    pagination?: Partial<IPaginationParams>,
    select?: string
  ) {
    return findAllWithPagination(Thread, where, pagination, select);
  }

  async delete(id: string) {
    const row = await Thread.findByPk(id);
    if (!row) return null;
    await row.destroy();
    await this.deleteCache(id);
    return row.toJSON() as any;
  }

  /**
   * Lock a thread - prevents new messages and reactions
   * @param threadId - The ID of the thread to lock
   * @param userId - The ID of the user locking the thread
   * @returns Promise<IBaseThread> - The updated thread
   */
  async lockThread(threadId: string, userId: string): Promise<IBaseThread> {
    const thread = await this.getById(threadId);
    if (!thread) {
      throw new BadRequestError("Thread not found");
    }

    if (isThreadLocked(thread)) {
      throw new BadRequestError("Thread is already locked");
    }

    // Only allow thread author to lock the thread
    if (thread.createdBy !== userId) {
      throw new ForbiddenError("Only the thread author can lock this thread");
    }

    const lockedThread = lockThread(thread, userId);
    
    const updated = await this.update(threadId, { lockHistory: lockedThread.lockHistory });
    
    return updated;
  }

  /**
   * Unlock a thread - allows new messages and reactions again
   * @param threadId - The ID of the thread to unlock
   * @param userId - The ID of the user unlocking the thread
   * @returns Promise<IBaseThread> - The updated thread
   */
  async unlockThread(threadId: string, userId: string): Promise<IBaseThread> {
    const thread = await this.getById(threadId);
    if (!thread) {
      throw new BadRequestError("Thread not found");
    }

    if (!isThreadLocked(thread)) {
      throw new BadRequestError("Thread is not locked");
    }

    // Only allow thread author to unlock the thread
    if (thread.createdBy !== userId) {
      throw new ForbiddenError("Only the thread author can unlock this thread");
    }

    const unlockedThread = unlockThread(thread);
    
    const updated = await this.update(threadId, { lockHistory: unlockedThread.lockHistory });
    
    return updated;
  }

  /**
   * Check if a thread and its parent chain is locked
   * @param threadId - The ID of the thread to check
   * @returns Promise<{isLocked: boolean, lockedThreadId?: string}> - Lock status and which thread is locked
   */
  async isThreadChainLocked(threadId: string): Promise<{isLocked: boolean, lockedThreadId?: string}> {
    const thread = await this.getById(threadId);
    if (!thread) {
      return { isLocked: false };
    }

    // Check if current thread is locked
    if (isThreadLocked(thread)) {
      return { isLocked: true, lockedThreadId: thread.id };
    }

    // Check if parent thread is locked (recursively)
    if (thread.parentId) {
      return await this.isThreadChainLocked(thread.parentId);
    }

    return { isLocked: false };
  }
}

export default ThreadsService;
