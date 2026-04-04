import { describe, expect, it } from 'vitest';

import { EEventStatus } from '@/definitions/enums';
import {
  buildActiveEventStatusPredicate,
  deriveEventStatus,
  resolveEventStatus,
  validateEventTimings,
} from '@/features/events/status';

describe('event status helpers', () => {
  it('derives upcoming and ongoing from event timings', () => {
    const now = new Date('2026-03-21T12:00:00.000Z');

    expect(
      deriveEventStatus(
        {
          start: '2026-03-21T13:00:00.000Z',
          end: '2026-03-21T15:00:00.000Z',
        },
        now,
      ),
    ).toBe(EEventStatus.Upcoming);

    expect(
      deriveEventStatus(
        {
          start: '2026-03-21T11:00:00.000Z',
          end: '2026-03-21T15:00:00.000Z',
        },
        now,
      ),
    ).toBe(EEventStatus.Ongoing);
  });

  it('resolves completed events as invalid for create/update timing flow', () => {
    const now = new Date('2026-03-21T12:00:00.000Z');

    expect(() =>
      resolveEventStatus(
        {
          start: '2026-03-21T08:00:00.000Z',
          end: '2026-03-21T11:00:00.000Z',
        },
        null,
        now,
      ),
    ).toThrow('Event end time must be in the future');
  });

  it('preserves cancelled status and validates max duration', () => {
    const now = new Date('2026-03-21T12:00:00.000Z');

    expect(
      resolveEventStatus(
        {
          start: '2026-03-21T08:00:00.000Z',
          end: '2026-03-21T13:00:00.000Z',
        },
        EEventStatus.Cancelled,
        now,
      ),
    ).toBe(EEventStatus.Cancelled);

    expect(() =>
      validateEventTimings(
        {
          start: '2026-03-21T08:00:00.000Z',
          end: '2026-03-29T08:00:00.000Z',
        },
        { now },
      ),
    ).toThrow('Event duration cannot exceed 7 days');
  });

  it('builds a db-safe active status predicate for enum-backed queries', () => {
    const predicate = buildActiveEventStatusPredicate({
      escape: (value) => `'${String(value)}'`,
    });

    expect(predicate).toContain('"status" IS NULL');
    expect(predicate).toContain(`'${EEventStatus.Cancelled}'`);
    expect(predicate).toContain(`'${EEventStatus.Draft}'`);
    expect(predicate).not.toContain("''");
    expect(predicate).not.toContain('COALESCE');
  });
});
