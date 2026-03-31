import type { IActivity, IMessage } from '@/definitions/types';
import {
  EActivityEntityType,
  EActivityType,
  EActivityVisibility,
} from '@/features/activity/constants';

type BuildMessageActivitiesInput = {
  actorId: string;
  message: IMessage;
  threadOwnerId?: string | null;
};

const getMessagePreview = (message: IMessage) => {
  const text = message.content?.text?.trim();
  if (text) return text;

  const mediaCount = message.content?.media?.length || 0;
  if (mediaCount > 0) {
    return mediaCount === 1 ? 'Sent an attachment' : `Sent ${mediaCount} attachments`;
  }

  return 'Sent a message';
};

export const buildMessageActivityPayload = (message: IMessage) => {
  const preview = getMessagePreview(message);

  return {
    message: preview,
    messageId: message.id,
    parentId: message.parentId,
    preview,
    threadId: message.threadId,
  };
};

export const buildMessageActivities = ({
  actorId,
  message,
  threadOwnerId,
}: BuildMessageActivitiesInput): Partial<IActivity>[] => {
  const payload = buildMessageActivityPayload(message);
  const entries: Partial<IActivity>[] = [
    {
      actorId,
      entityId: message.id,
      entityType: EActivityEntityType.Message,
      payload,
      type: EActivityType.MessageCreated,
      visibility: EActivityVisibility.Public,
    },
  ];

  if (threadOwnerId && threadOwnerId !== actorId) {
    entries.push({
      actorId,
      entityId: message.id,
      entityType: EActivityEntityType.Message,
      payload,
      readAt: null,
      recipientId: threadOwnerId,
      type: EActivityType.MessageCreated,
      visibility: EActivityVisibility.Private,
    });
  }

  return entries;
};
