export const ENTITY_ENGAGEMENT_TABLE_NAME = 'EntityEngagements';
export const ENTITY_RATING_TABLE_NAME = 'EntityRatings';

export const SUPPORTED_ENGAGEMENT_ENTITY_TYPES = ['users', 'events', 'threads', 'messages'] as const;

export type SupportedEngagementEntityType = (typeof SUPPORTED_ENGAGEMENT_ENTITY_TYPES)[number];
