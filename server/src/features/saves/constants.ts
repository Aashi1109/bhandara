export const SAVED_ENTITY_TABLE_NAME = 'SavedEntities';

export const SUPPORTED_SAVED_ENTITY_TYPES = [
  'event',
  'thread',
  'message',
  'user',
] as const;

export type SupportedSavedEntityType =
  (typeof SUPPORTED_SAVED_ENTITY_TYPES)[number];
