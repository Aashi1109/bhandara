import { IBaseThread, ILockHistory } from "@/definitions/types";

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
 * Check if a user can lock/unlock a thread (only thread author)
 * @param thread - The thread object
 * @param userId - The user ID to check permissions for
 * @returns boolean - true if the user can lock/unlock the thread, false otherwise
 */
export const canUserLockThread = (thread: IBaseThread, userId: string): boolean => {
  return thread.createdBy === userId;
};

/**
 * Get a human-readable lock status message
 * @param thread - The thread object
 * @param currentUserId - The current user's ID
 * @returns string - A message describing the lock status
 */
export const getThreadLockStatusMessage = (thread: IBaseThread, currentUserId?: string): string => {
  if (!isThreadLocked(thread)) {
    return "";
  }
  
  const lockInfo = getThreadLockInfo(thread);
  if (!lockInfo) {
    return "";
  }
  
  const isCurrentUser = currentUserId === lockInfo.lockedBy;
  const lockDate = new Date(lockInfo.lockedAt).toLocaleDateString();
  
  if (isCurrentUser) {
    return `You locked this thread on ${lockDate}`;
  } else {
    return `This thread was locked on ${lockDate}`;
  }
};