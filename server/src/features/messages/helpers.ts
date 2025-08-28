import { CACHE_NAMESPACE_CONFIG } from "@/constants";
import { IMessage } from "@/definitions/types";
import { RedisCache } from "@/features/cache";

const messagesCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Messages.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Messages.ttl,
});

export const getMessageCache = async (id: string) => {
  return await messagesCache.getItem<IMessage>(id);
};

export const setMessageCache = async (id: string, data: IMessage) => {
  return await messagesCache.setItem(id, data);
};

export const deleteMessageCache = async (id: string) => {
  return await messagesCache.deleteItem(id);
};
