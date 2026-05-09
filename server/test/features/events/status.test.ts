import { describe, expect, it } from 'vitest';

import { EEventStatus } from '@/common/definitions/enums';
import {
  buildActiveEventStatusPredicate,
  deriveEventStatus,
  resolvePersistedEventState,
  validateEventTimings,
} from '@/features/events/status';

describe('event status helpers', () => {
  it('derives upcoming and ongoing from event timings', () => {
    const now = new Date('2026-03-21T12:00:00.000Z');

    expect(
      deriveEventStatus(
        {
          startTime: '2026-03-21T13:00:00.000Z',
          endTime: '2026-03-21T15:00:00.000Z',
        },
        now,
      ),
    ).toBe(EEventStatus.Upcoming);

    expect(
      deriveEventStatus(
        {
          startTime: '2026-03-21T11:00:00.000Z',
          endTime: '2026-03-21T15:00:00.000Z',
        },
        now,
      ),
    ).toBe(EEventStatus.Ongoing);
  });

  it('rejects completed events in create/update timing validation flow', () => {
    const now = new Date('2026-03-21T12:00:00.000Z');

    expect(() =>
      validateEventTimings(
        {
          startTime: '2026-03-21T08:00:00.000Z',
          endTime: '2026-03-21T11:00:00.000Z',
        },
        { now },
      ),
    ).toThrow('Event end time must be in the future');
  });

  it('resolves persisted draft/cancelled state separately from derived time status', () => {
    const now = new Date('2026-03-21T12:00:00.000Z');

    expect(
      deriveEventStatus({
        startTime: '2026-03-21T08:00:00.000Z',
        endTime: '2026-03-21T13:00:00.000Z',
        isDraft: true,
      }),
    ).toBe(EEventStatus.Draft);

    expect(
      deriveEventStatus({
        startTime: '2026-03-21T08:00:00.000Z',
        endTime: '2026-03-21T13:00:00.000Z',
        cancelledAt: '2026-03-21T10:00:00.000Z',
      }),
    ).toBe(EEventStatus.Cancelled);

    expect(resolvePersistedEventState(EEventStatus.Cancelled)).toMatchObject({
      isDraft: false,
    });
    expect(resolvePersistedEventState(EEventStatus.Draft)).toEqual({
      isDraft: true,
      cancelledAt: null,
    });
    expect(resolvePersistedEventState(EEventStatus.Upcoming)).toEqual({
      isDraft: false,
      cancelledAt: null,
    });

    expect(() =>
      validateEventTimings(
        {
          startTime: '2026-03-21T08:00:00.000Z',
          endTime: '2026-03-29T08:00:00.000Z',
        },
        { now },
      ),
    ).toThrow('Event duration cannot exceed 7 days');
  });

  it('builds a db-safe active status predicate for enum-backed queries', () => {
    const predicate = buildActiveEventStatusPredicate();

    expect(predicate).toContain('"cancelledAt" IS NULL');
    expect(predicate).toContain('COALESCE("isDraft", false) = false');
  });
});
