import { describe, expect, it } from "vitest";
import { cacheKeys } from "@/features/cache/keys";

describe("cache key compaction", () => {
  it("builds compact engagement keys", () => {
    expect(cacheKeys.engagementAggregate("events", "evt-1")).toBe("eg:e:evt-1");
    expect(
      cacheKeys.engagementViewDedupe("messages", "msg-1", "2026-03-23", "viewer-1"),
    ).toBe("egv:m:msg-1:2026-03-23:viewer-1");
  });

  it("builds compact stats keys", () => {
    expect(cacheKeys.stats("events", "evt-1")).toBe("e:evt-1");
    expect(cacheKeys.stats("threads", "thr-1")).toBe("t:thr-1");
    expect(cacheKeys.stats("messages", "msg-1")).toBe("m:msg-1");
  });

  it("builds compact helper keys", () => {
    expect(cacheKeys.activityItem("act-1")).toBe("i:act-1");
    expect(cacheKeys.userActivityPattern("user-1")).toBe("u:user-1:a:*");
    expect(cacheKeys.userUpdatesPattern("user-1")).toBe("u:user-1:u:*");
    expect(cacheKeys.achievementProgress("user-1")).toBe("u:user-1:p");
    expect(cacheKeys.exploreCursor("user-1")).toBe("u:user-1:c");
  });
});
