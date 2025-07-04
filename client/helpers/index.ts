import { v7, v4 } from "uuid";

/**
 * Debounce calls to the provided function.
 */
export const debounce = <T extends (...args: any[]) => any>(
  func: T,
  wait: number
): ((...args: Parameters<T>) => void) => {
  let timeout: NodeJS.Timeout;

  return (...args: Parameters<T>) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => func(...args), wait);
  };
};

/** Return a RFC4122 v7 UUID. */
export const getUUIDv7 = () => v7();

/** Return a RFC4122 v4 UUID. */
export const getUUIDv4 = () => v4();

/**
 * Converts a distance in meters to a readable string.
 * e.g., 30 → '30m', 1500 → '1.5 km', 1609 → '1 mi'
 */
export function formatDistance(meters: number, unitSystem: "metric" | "imperial" = "metric"): string {
  if (unitSystem === "imperial") {
    const miles = meters / 1609.344;
    if (miles < 0.1) {
      const feet = meters * 3.28084;
      return `${Math.round(feet)} ft`;
    }
    return `${miles.toFixed(miles < 10 ? 1 : 0)} mi`;
  }

  // metric system
  if (meters < 1000) {
    return `${Math.round(meters)} m`;
  }

  const km = meters / 1000;
  return `${km.toFixed(km < 10 ? 1 : 0)} km`;
}
