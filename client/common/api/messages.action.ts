import type { IPaginationParams } from "@/definitions/types";
import axiosClient from "./base";
import { formTruthyValues } from "@/utils";

type GetMessagesForThreadProps = {
  threadId: string;
  pagination?: Partial<IPaginationParams>;
};

type GetChildMessagesForThreadProps = {
  threadId: string;
  parentId: string;
  pagination?: Partial<IPaginationParams>;
};

type GetMessageByIdProps = {
  threadId: string;
  messageId: string;
};

export const getMessagesForThread = async ({ threadId, pagination }: GetMessagesForThreadProps) => {
  const queryParams = new URLSearchParams(formTruthyValues(pagination || {}));
  const messagesResponse = await axiosClient.get(`/threads/${threadId}/messages?${queryParams.toString()}`);
  return messagesResponse.data;
};

export const getChildMessagesForThread = async ({ threadId, parentId, pagination }: GetChildMessagesForThreadProps) => {
  const queryParams = new URLSearchParams(formTruthyValues(pagination || {}));

  const response = await axiosClient.get(`/threads/${threadId}/child-messages/${parentId}?${queryParams.toString()}`);
  return response.data;
};

export const getMessageById = async ({ threadId, messageId }: GetMessageByIdProps) => {
  const response = await axiosClient.get(`/threads/${threadId}/messages/${messageId}`);
  return response.data;
};
