import { describe, expect, it } from 'vitest';
import { EEventStatus } from '@/definitions/enums';
import { buildActiveEventStatusPredicate } from '@/features/events/status';

describe('event status helpers', () => {
  it('builds a null-safe predicate for active statuses', () => {
    const predicate = buildActiveEventStatusPredicate({
      escape: (value) => `'${String(value).replace(/'/g, "''")}'`,
    });

    expect(predicate).toBe(`("status" IS NULL OR "status" NOT IN ('cancelled', 'draft'))`);
    expect(predicate).toContain(EEventStatus.Cancelled);
    expect(predicate).toContain(EEventStatus.Draft);
    expect(predicate).not.toContain(`COALESCE("status", '')`);
  });
});
