import { describe, expect, it } from 'vitest';

import { buildEventVisibilitySql } from '@/features/events/model';

const VIEWER = '11111111-1111-1111-1111-111111111111';

describe('buildEventVisibilitySql', () => {
  it('restricts anonymous viewers to public events', () => {
    const sql = buildEventVisibilitySql();

    expect(sql).toBe(`"visibility" = 'public'`);
    expect(sql).not.toContain('EventParticipants');
    expect(sql).not.toContain('createdBy');
  });

  it('lets a viewer see public events, their own, and ones they participate in', () => {
    const sql = buildEventVisibilitySql(VIEWER);

    expect(sql).toContain(`"visibility" = 'public'`);
    expect(sql).toContain(`"createdBy" = '${VIEWER}'`);
    expect(sql).toContain('FROM "EventParticipants" ep');
    expect(sql).toContain(`ep."status" <> 'declined'`);
  });

  it('escapes the viewer id instead of interpolating it', () => {
    const sql = buildEventVisibilitySql("' OR 1=1 --");

    // A raw break-out would leave a bare `' OR 1=1 --` in the predicate; the
    // escaped form doubles the quote and stays inside the string literal.
    expect(sql).toContain(`''' OR 1=1 --'`);
  });

  it('qualifies the participation lookup with the caller-supplied id column', () => {
    // The Sequelize builder aliases the table to "Event"; the raw marker SQL
    // uses "Events". A wrong alias makes the EXISTS correlate to nothing.
    expect(buildEventVisibilitySql(VIEWER, '"Event"."id"')).toContain('ep."eventId" = "Event"."id"');
    expect(buildEventVisibilitySql(VIEWER)).toContain('ep."eventId" = "Events"."id"');
  });
});
