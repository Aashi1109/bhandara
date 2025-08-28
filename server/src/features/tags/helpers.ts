import { ITag } from "@/definitions/types";
import { RedisCache } from "@/features/cache";
import { CACHE_NAMESPACE_CONFIG } from "@/constants";
import logger from "@/logger";
import { isEmpty, jnstringify } from "@/utils";

const tagCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Tags.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Tags.ttl,
});

const eventTagsCache = new RedisCache({
  namespace: CACHE_NAMESPACE_CONFIG.Events.namespace,
  defaultTTLSeconds: CACHE_NAMESPACE_CONFIG.Events.ttl,
});

export const getTagCache = (tagId: string) => tagCache.getItem<ITag>(tagId);

export const setTagCache = (tagId: string, tag: ITag) =>
  tagCache.setItem(tagId, tag);

export const deleteTagCache = (tagId: string) => tagCache.deleteItem(tagId);

export const setEventTagsCache = async (
  eventId: string,
  tags: ITag[]
): Promise<"OK"> => {
  const pipeline = eventTagsCache.getPipeline();
  const eventTagsKey = `${CACHE_NAMESPACE_CONFIG.Events.namespace}:${eventId}:tags`;
  tags.forEach((tag) => {
    pipeline.hset(eventTagsKey, {
      [tag.id]: jnstringify(tag),
    });
  });
  pipeline.expire(eventTagsKey, eventTagsCache.defaultTTLMs);
  const res = await pipeline.exec();
  logger.debug(
    `Result set event tags cache for event ${eventId}: ${jnstringify(res)}`
  );
  return "OK";
};

export const getEventTagsCache = async (eventId: string) => {
  const tags = await eventTagsCache.getHKeys(`${eventId}:tags`);
  const formattedTags = Object.keys(tags).map(
    (tag) => JSON.parse(tags[tag]) as ITag
  );
  return isEmpty(formattedTags) ? null : formattedTags;
};

export const deleteEventTagsCache = (eventId: string) =>
  eventTagsCache.deleteItem(`${eventId}:tags`);

export const getSubTagsCache = (tagId: string) =>
  tagCache.getItem<ITag[]>(`${tagId}:sub-tags`);

export const setSubTagsCache = (tagId: string, tags: ITag[]) =>
  tagCache.setItem(`${tagId}:sub-tags`, tags, 3600);

export const deleteSubTagsCache = (tagId: string) =>
  tagCache.deleteItem(`${tagId}:sub-tags`);
