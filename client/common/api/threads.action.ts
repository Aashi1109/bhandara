import { formTruthyValues, isEmpty } from "@/utils";
import axiosClient from "./base";
import { IPaginationParams } from "@/definitions/types";

type GetThreadByIdParams = {
  id: string;
  includeMessages?: boolean | number;
};

export const getThreadById = async ({ id, includeMessages = false }: GetThreadByIdParams) => {
  const threadResponse = await axiosClient.get(`/threads/${id}?includeMessage=${includeMessages}`);
  return threadResponse.data;
};

/**
 * Lock a thread (author only)
 * @param threadId - The ID of the thread to lock
 * @returns Promise with the locked thread data
 */
export const lockThread = async (threadId: string): Promise<any> => {
  try {
    const response = await axiosClient.post(`/threads/${threadId}/lock`);
    return response.data;
  } catch (error) {
    console.error("Error locking thread:", error);
    throw error;
  }
};

/**
 * Unlock a thread (author only)
 * @param threadId - The ID of the thread to unlock
 * @returns Promise with the unlocked thread data
 */
export const unlockThread = async (threadId: string): Promise<any> => {
  try {
    const response = await axiosClient.post(`/threads/${threadId}/unlock`);
    return response.data;
  } catch (error) {
    console.error("Error unlocking thread:", error);
    throw error;
  }
};
