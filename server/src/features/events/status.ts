import { BadRequestError } from '@/exceptions';
import { EEventStatus } from '@/definitions/enums';

type EventTimingInput = {
  start: string | Date;
  end: string | Date;
};

export const asDate = (value: string | Date) => (value instanceof Date ? value : new Date(value));

export const deriveEventStatus = (timings: EventTimingInput, now: Date = new Date()): EEventStatus => {
  const start = asDate(timings.start);
  const end = asDate(timings.end);

  if (now >= end) {
    return EEventStatus.Completed;
  }

  if (now >= start) {
    return EEventStatus.Ongoing;
  }

  return EEventStatus.Upcoming;
};

export const buildActiveEventStatusPredicate = ({
  escape,
  statusColumn = '"status"',
}: {
  escape: (value: string | number | Date) => string;
  statusColumn?: string;
}) =>
  `(${statusColumn} IS NULL OR ${statusColumn} NOT IN (${escape(EEventStatus.Cancelled)}, ${escape(EEventStatus.Draft)}))`;

export const validateEventTimings = (
  timings: EventTimingInput,
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
  if (!timings?.start || !timings?.end) {
    throw new BadRequestError('Start time and end time are required');
  }

  const startTime = asDate(timings.start);
  const endTime = asDate(timings.end);

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

export const resolveEventStatus = (timings: EventTimingInput, status?: string | null, now: Date = new Date()) => {
  if (status === EEventStatus.Cancelled) {
    return EEventStatus.Cancelled;
  }

  validateEventTimings(timings, { now, allowCompleted: false });
  return deriveEventStatus(timings, now);
};
