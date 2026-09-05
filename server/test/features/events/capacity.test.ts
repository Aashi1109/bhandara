import { describe, expect, it } from 'vitest';

import { hasSeatAvailable } from '@/features/events/model';

describe('hasSeatAvailable', () => {
  it('treats a missing capacity as unlimited', () => {
    expect(hasSeatAvailable(null, 0)).toBe(true);
    expect(hasSeatAvailable(null, 10_000)).toBe(true);
    expect(hasSeatAvailable(undefined, 10_000)).toBe(true);
  });

  it('fills the last seat but not one more', () => {
    // Off-by-one here either loses a seat on every event or oversells by one.
    expect(hasSeatAvailable(50, 48)).toBe(true);
    expect(hasSeatAvailable(50, 49)).toBe(true);
    expect(hasSeatAvailable(50, 50)).toBe(false);
    expect(hasSeatAvailable(50, 51)).toBe(false);
  });

  it('treats capacity 0 as closed, not as unlimited', () => {
    expect(hasSeatAvailable(0, 0)).toBe(false);
  });
});
