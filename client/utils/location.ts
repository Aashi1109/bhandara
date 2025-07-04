import * as Location from "expo-location";

/** Request device location permissions and return the current position. */
export async function askForLocation(
  onLocationGetSuccess?: (location: Location.LocationObject) => Promise<void> | void,
  onLocationGetFailed?: (resp: Location.LocationPermissionResponse) => void
) {
  try {
    const response = await Location.requestForegroundPermissionsAsync();
    if (response.status !== "granted") {
      onLocationGetFailed?.(response);
      return;
    }

    const location = await Location.getCurrentPositionAsync({});

    if (onLocationGetSuccess) await onLocationGetSuccess(location);
    return location;
  } catch (error: any) {
    onLocationGetFailed?.(error);
  }
}

interface CoordPoint {
  longitude: number;
  latitude: number;
}

/**
 * Calculate the distance between two coordinate points in meters.
 */
export function haversineDistanceInM(start: CoordPoint, end: CoordPoint): number {
  const toRad = (x: number) => (x * Math.PI) / 180;

  const R = 6371; // Earth radius in kilometers

  const dLat = toRad(end.latitude - start.latitude);
  const dLon = toRad(end.longitude - start.longitude);

  const lat1Rad = toRad(start.latitude);
  const lat2Rad = toRad(end.latitude);

  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1Rad) * Math.cos(lat2Rad) * Math.sin(dLon / 2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c * 1000; // Return in meters
}
