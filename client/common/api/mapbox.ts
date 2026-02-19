import config from "@/config";
import type { IAddress } from "@/definitions/types";
import axios from "axios";

export const suggestSearchResults = async ({
  search,
  proximity,
  sessionToken
}: {
  search: string;
  proximity?: [number, number];
  sessionToken: string;
}) => {
  const queryParams = new URLSearchParams();
  queryParams.set("access_token", config.mapbox.accessToken);
  queryParams.set("session_token", sessionToken);
  queryParams.set("q", search);
  queryParams.set("language", "en");

  if (proximity) {
    queryParams.set("proximity", proximity.join(","));
  }

  const response = await axios.get(`https://api.mapbox.com/search/searchbox/v1/suggest?${queryParams.toString()}`);
  return response.data.suggestions;
};

export const retrieveSearchItem = async ({ mapboxId, sessionToken }: { mapboxId: string; sessionToken: string }) => {
  const response = await axios.get(
    `https://api.mapbox.com/search/searchbox/v1/retrieve/${mapboxId}?session_token=${sessionToken}&access_token=${config.mapbox.accessToken}`
  );
  return response.data.features[0];
};

export const getAddressFromCoordinates = async ({
  latitude,
  longitude
}: {
  latitude: number;
  longitude: number;
}): Promise<IAddress | null> => {
  const queryParams = new URLSearchParams();
  queryParams.set("access_token", config.mapbox.accessToken);
  queryParams.set("longitude", longitude.toString());
  queryParams.set("latitude", latitude.toString());
  queryParams.set("language", "en");
  queryParams.set("limit", "1");
  const url = `https://api.mapbox.com/search/geocode/v6/reverse?${queryParams.toString()}`;
  const response = await axios.get(url);

  const feature = response.data.features[0];

  if (!feature) return null;

  const contextKeyAlias = {
    place: "city",
    region: "state",
    address: "place"
  };

  const addressInfo: Record<string, string> = {};

  Object.entries(feature.properties.context).forEach(([key, value]: [string, any]) => {
    const alias = contextKeyAlias[key as keyof typeof contextKeyAlias];
    addressInfo[alias || key] = value.name;
  });

  return {
    address: feature.properties.full_address,
    ...addressInfo
  } as any;
};

interface IGSMParams {
  latitude: number;
  longitude: number;
  zoom?: number;
  pitch?: number;
  bearing?: number;
  width?: number;
  height?: number;
  theme?: "light-v11" | "dark-v11";
  markerConfig?: {
    color: string;
    size: "s" | "l";
  };
}

export const getStaticMapImageUrl = ({
  latitude,
  longitude,
  zoom,
  pitch,
  bearing,
  width,
  height,
  theme,
  markerConfig
}: IGSMParams) => {
  // Default values
  const _defaults = {
    theme: "light-v11", // Default Mapbox style
    width: 300, // Default image width
    height: 200, // Default image height
    zoom: 12, // Default zoom level
    pitch: 15, // Default pitch (tilt angle)
    bearing: 60 // Default bearing (rotation angle)
  };

  // Validate latitude and longitude if a pin is included
  if (markerConfig && (!latitude || !longitude)) {
    throw new Error("Latitude and longitude are required to include a pin marker.");
  }

  // Construct the Mapbox Static Images API URL
  const baseUrl =
    `https://api.mapbox.com/styles/v1/mapbox/${theme || _defaults.theme}/static/${ 
    markerConfig ? `pin-${markerConfig.size}+${markerConfig.color}(${longitude},${latitude})/` : ""  // Include pin only if requested
    }${longitude || 0},${latitude || 0},${zoom || _defaults.zoom},${pitch || _defaults.pitch},${bearing || _defaults.bearing}/` +
    `${width || _defaults.width}x${height || _defaults.height}` +
    `?access_token=${config.mapbox.accessToken}`;

  return baseUrl;
};
