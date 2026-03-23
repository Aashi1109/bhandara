import { describe, expect, it } from "vitest";

import {
  buildSeedUserEmailLikePattern,
  chunkArray,
  computeWorkerCount,
  deriveHierarchyLowerBound,
  deriveHierarchicalRange,
  distributeTotalAcrossKeys,
  parseOptions,
  resolveRangeForKey,
  shardSeedUsers,
} from "@/misc/seeder/utils";

describe("seeder utils", () => {
  it("chunks rows into fixed-size batches", () => {
    expect(chunkArray([1, 2, 3, 4, 5], 2)).toEqual([[1, 2], [3, 4], [5]]);
  });

  it("rejects non-positive chunk sizes", () => {
    expect(() => chunkArray([1, 2, 3], 0)).toThrow("chunkSize must be greater than 0");
  });

  it("parses reuse and worker flags", () => {
    const options = parseOptions([
      "--users=5",
      "--reuse-existing-users=true",
      "--reuse-max-users=3",
      "--seed-workers=4",
    ]);

    expect(options.reuseExistingUsers).toBe(true);
    expect(options.reuseMaxUsers).toBe(3);
    expect(options.seedWorkers).toBe(4);
  });

  it("computes worker count with cpu and user caps", () => {
    expect(computeWorkerCount(undefined, 3, 12)).toBe(3);
    expect(computeWorkerCount(undefined, 20, 12)).toBe(8);
    expect(computeWorkerCount(16, 5, 12)).toBe(5);
  });

  it("shards users evenly across workers", () => {
    const shards = shardSeedUsers(
      [
        { id: "1", email: "seed.a@bhandara.dev", name: "A", source: "existing" as const },
        { id: "2", email: "seed.b@bhandara.dev", name: "B", source: "existing" as const },
        { id: "3", email: "seed.c@bhandara.dev", name: "C", source: "created" as const },
        { id: "4", email: "seed.d@bhandara.dev", name: "D", source: "created" as const },
      ],
      2,
    );

    expect(shards).toEqual([
      [
        { id: "1", email: "seed.a@bhandara.dev", name: "A", source: "existing" },
        { id: "3", email: "seed.c@bhandara.dev", name: "C", source: "created" },
      ],
      [
        { id: "2", email: "seed.b@bhandara.dev", name: "B", source: "existing" },
        { id: "4", email: "seed.d@bhandara.dev", name: "D", source: "created" },
      ],
    ]);
  });

  it("builds the reusable user email pattern from the seed prefix", () => {
    expect(buildSeedUserEmailLikePattern("seed")).toBe("seed.%@bhandara.dev");
  });

  it("derives hierarchy-based lower bounds for fixed fanout counts", () => {
    expect(deriveHierarchicalRange({ min: 100, max: 100 }, "event")).toEqual({ min: 50, max: 100 });
    expect(deriveHierarchicalRange({ min: 100, max: 100 }, "thread")).toEqual({ min: 30, max: 100 });
    expect(deriveHierarchicalRange({ min: 100, max: 100 }, "message")).toEqual({ min: 10, max: 100 });
  });

  it("preserves explicit ranges when provided", () => {
    expect(deriveHierarchicalRange({ min: 20, max: 100 }, "event")).toEqual({ min: 20, max: 100 });
  });

  it("calculates hierarchy lower bounds for other values too", () => {
    expect(deriveHierarchyLowerBound(20, "event")).toBe(10);
    expect(deriveHierarchyLowerBound(20, "thread")).toBe(6);
    expect(deriveHierarchyLowerBound(20, "message")).toBe(2);
    expect(deriveHierarchyLowerBound(500, "thread")).toBe(150);
    expect(deriveHierarchyLowerBound(20000, "message")).toBe(2000);
  });

  it("distributes totals exactly across keys", () => {
    const counts = distributeTotalAcrossKeys(2000, [
      "user-a",
      "user-b",
      "user-c",
      "user-d",
      "user-e",
    ]);

    expect(counts.reduce((sum, count) => sum + count, 0)).toBe(2000);
  });

  it("can balance totals evenly when randomness is disabled", () => {
    const counts = distributeTotalAcrossKeys(
      2000,
      ["user-a", "user-b", "user-c", "user-d", "user-e", "user-f", "user-g", "user-h", "user-i", "user-j"],
      {
        randomnessFactor: 0,
      },
    );

    expect(counts.reduce((sum, count) => sum + count, 0)).toBe(2000);
    expect(Math.max(...counts) - Math.min(...counts)).toBeLessThanOrEqual(1);
  });

  it("respects zero-weight keys when distributing totals", () => {
    const counts = distributeTotalAcrossKeys(50, ["a", "b", "c"], {
      baseWeights: [1, 0, 2],
    });

    expect(counts[1]).toBe(0);
    expect(counts.reduce((sum, count) => sum + count, 0)).toBe(50);
  });

  it("resolves deterministic ranges for the same key", () => {
    expect(resolveRangeForKey({ min: 10, max: 20 }, "same-key")).toBe(
      resolveRangeForKey({ min: 10, max: 20 }, "same-key"),
    );
  });
});
