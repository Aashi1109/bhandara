import { CACHE_NAMESPACE_CONFIG } from "@constants";
import { IBaseThread } from "@definitions/types";
import { RedisCache } from "@features/cache";

const threadsCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Threads.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Threads.ttl,
});

export const getThreadCache = async (id: string) => {
  return await threadsCache.getItem<IBaseThread>(id);
};

export const setThreadCache = async (id: string, data: IBaseThread) => {
  return await threadsCache.setItem(id, data);
};

export const deleteThreadCache = async (id: string) => {
  return await threadsCache.deleteItem(id);
};

/**
 * Check if a thread is currently locked
 * @param thread - The thread object to check
 * @returns boolean - true if the thread is locked, false otherwise
 */
export const isThreadLocked = (thread: IBaseThread): boolean => {
  if (!thread.lockHistory || thread.lockHistory.length === 0) {
    return false;
  }
  
  // Get the latest lock entry (assuming the array is chronologically ordered)
  const latestLock = thread.lockHistory[thread.lockHistory.length - 1];
  
  // If there's a lock entry, the thread is locked
  return !!latestLock.lockedBy && !!latestLock.lockedAt;
};

/**
 * Get the current lock information for a thread
 * @param thread - The thread object to check
 * @returns ILockHistory | null - the lock info if locked, null if not locked
 */
export const getThreadLockInfo = (thread: IBaseThread): ILockHistory | null => {
  if (!isThreadLocked(thread)) {
    return null;
  }
  
  return thread.lockHistory[thread.lockHistory.length - 1];
};

/**
 * Check if a user can modify a locked thread (only the locker or creator can unlock)
 * @param thread - The thread object
 * @param userId - The user ID to check permissions for
 * @returns boolean - true if the user can modify the thread, false otherwise
 */
export const canUserModifyLockedThread = (thread: IBaseThread, userId: string): boolean => {
  if (!isThreadLocked(thread)) {
    return true; // Not locked, anyone can modify
  }
  
  const lockInfo = getThreadLockInfo(thread);
  if (!lockInfo) {
    return true;
  }
  
  // User can modify if they are the locker or the thread creator
  return lockInfo.lockedBy === userId || thread.createdBy === userId;
};

/**
 * Lock a thread
 * @param thread - The thread object to lock
 * @param userId - The user ID who is locking the thread
 * @returns IBaseThread - the updated thread object
 */
export const lockThread = (thread: IBaseThread, userId: string): IBaseThread => {
  const lockEntry: ILockHistory = {
    lockedBy: userId,
    lockedAt: new Date(),
  };
  
  const updatedThread = {
    ...thread,
    lockHistory: [...(thread.lockHistory || []), lockEntry],
  };
  
  return updatedThread;
};

/**
 * Unlock a thread
 * @param thread - The thread object to unlock
 * @returns IBaseThread - the updated thread object
 */
export const unlockThread = (thread: IBaseThread): IBaseThread => {
  return {
    ...thread,
    lockHistory: [], // Clear lock history to unlock
  };
};
