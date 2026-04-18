import { BadRequestError } from '@/exceptions';
import { EEventStatus } from '@/definitions/enums';

type EventStatusInput = {
  startTime: string | Date;
  endTime: string | Date;
  isDraft?: boolean;
  cancelledAt?: string | Date | null;
};

export const asDate = (value: string | Date) => (value instanceof Date ? value : new Date(value));

export const deriveEventStatus = (event: EventStatusInput, now: Date = new Date()): EEventStatus => {
  if (event.cancelledAt) {
    return EEventStatus.Cancelled;
  }

  if (event.isDraft) {
    return EEventStatus.Draft;
  }

  const start = asDate(event.startTime);
  const end = asDate(event.endTime);

  if (now >= end) {
    return EEventStatus.Completed;
  }

  if (now >= start) {
    return EEventStatus.Ongoing;
  }

  return EEventStatus.Upcoming;
};

export const buildActiveEventStatusPredicate = ({
  draftColumn = '"isDraft"',
  cancelledAtColumn = '"cancelledAt"',
}: {
  draftColumn?: string;
  cancelledAtColumn?: string;
} = {}) => `(${cancelledAtColumn} IS NULL AND COALESCE(${draftColumn}, false) = false)`;

export const validateEventTimings = (
  event: Pick<EventStatusInput, 'startTime' | 'endTime'>,
  {
    now = new Date(),
    allowCompleted = false,
    maxDurationMs = 7 * 24 * 60 * 60 * 1000,
  }: {
    now?: Date;
    allowCompleted?: boolean;
    maxDurationMs?: number;
  } = {},
) => {
  if (!event?.startTime || !event?.endTime) {
    throw new BadRequestError('Start time and end time are required');
  }

  const startTime = asDate(event.startTime);
  const endTime = asDate(event.endTime);

  if (Number.isNaN(startTime.getTime()) || Number.isNaN(endTime.getTime())) {
    throw new BadRequestError('Start time and end time must be valid dates');
  }

  if (endTime <= startTime) {
    throw new BadRequestError('End time must be after start time');
  }

  if (endTime.getTime() - startTime.getTime() > maxDurationMs) {
    throw new BadRequestError('Event duration cannot exceed 7 days');
  }

  if (!allowCompleted && endTime <= now) {
    throw new BadRequestError('Event end time must be in the future');
  }
};

export const resolvePersistedEventState = (
  status: string | null | undefined,
  existing?: {
    isDraft?: boolean;
    cancelledAt?: string | Date | null;
  },
) => {
  if (status === EEventStatus.Cancelled) {
    return {
      isDraft: false,
      cancelledAt: existing?.cancelledAt ? asDate(existing.cancelledAt) : new Date(),
    };
  }

  if (status === EEventStatus.Draft) {
    return {
      isDraft: true,
      cancelledAt: null,
    };
  }

  if (status === EEventStatus.Upcoming || status === EEventStatus.Ongoing || status === EEventStatus.Completed) {
    return {
      isDraft: false,
      cancelledAt: null,
    };
  }

  return {
    isDraft: existing?.isDraft ?? false,
    cancelledAt: existing?.cancelledAt ? asDate(existing.cancelledAt) : null,
  };
};
