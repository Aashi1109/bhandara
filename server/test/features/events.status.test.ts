import { describe, expect, it } from 'vitest';
import { buildActiveEventStatusPredicate } from '@/features/events/status';

describe('event status helpers', () => {
  it('builds a null-safe predicate for active statuses', () => {
    const predicate = buildActiveEventStatusPredicate();

    expect(predicate).toBe('("cancelledAt" IS NULL AND COALESCE("isDraft", false) = false)');
  });
});
