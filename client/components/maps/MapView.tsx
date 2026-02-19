import { StyleSheet } from "react-native";
import Mapbox, {
  MapView,
  UserTrackingMode,
  Camera,
  PointAnnotation,
  UserLocation
} from "@rnmapbox/maps";
import config from "@/config";
import { useEffect, useRef, useState, type RefObject } from "react";

Mapbox.setAccessToken(config.mapbox.accessToken);

Mapbox.setTelemetryEnabled(false);

const styles = StyleSheet.create({
  map: {
    flex: 1,
    height: "100%",
    width: "100%"
  }
});

export default function MapViewComponent({
  consumerRef,
  initialLocation,
  searchRef
}: {
  consumerRef: RefObject<any>;
  initialLocation?: number[];
  searchRef: RefObject<{ setCallBack: (callback: (result: any) => void) => void }>;
}) {
  const cameraRef = useRef<Camera>(null);
  const [markerCoords, setMarkerCoords] = useState<number[] | undefined>(initialLocation);
  const currentLocationRef = useRef<number[] | undefined>(initialLocation);

  const flyTo = (coords: number[]) => {
    cameraRef.current?.setCamera({
      centerCoordinate: coords as [number, number],
      zoomLevel: 14,
      animationDuration: 1000
    });
  };

  const runConsumerCallbacks = (data: Record<string, any>) => {
    Object.values(consumerRef.current || {}).forEach((value) => {
      if (typeof value === "function") {
        value(data);
      }
    });
  };

  const handleSearchResultSelect = (result: any) => {
    const coords = result.geometry.coordinates;
    setMarkerCoords(coords);
    flyTo(coords);
  };

  useEffect(() => {
    searchRef.current?.setCallBack(handleSearchResultSelect);
  }, [searchRef.current]);

  useEffect(() => {
    if (initialLocation) {
      setMarkerCoords(initialLocation);
      flyTo(initialLocation);
    }
  }, [initialLocation]);

  const onUserLocationUpdate = (loc: any) => {
    currentLocationRef.current = [loc.coords.longitude, loc.coords.latitude];
    runConsumerCallbacks({
      "map:geolocate": {
        longitude: loc.coords.longitude,
        latitude: loc.coords.latitude
      }
    });
  };

  const onMapPress = (e: any) => {
    const coords = e.geometry.coordinates as number[];
    setMarkerCoords(coords);
    flyTo(coords);
    runConsumerCallbacks({
      "marker:change": { longitude: coords[0], latitude: coords[1] }
    });
  };

  const onMarkerDragEnd = (e: any) => {
    const coords = e.geometry.coordinates as number[];
    setMarkerCoords(coords);
    flyTo(coords);
    runConsumerCallbacks({
      "marker:dragend": { longitude: coords[0], latitude: coords[1] }
    });
  };

  return (
    <MapView
      style={styles.map}
      compassEnabled
      zoomEnabled
      onPress={onMapPress}
    >
      <Camera
        ref={cameraRef}
        centerCoordinate={markerCoords || [77.46183, 22.76583]}
        followUserMode={UserTrackingMode.Follow}
        followUserLocation={false}
        zoomLevel={14}
      />

      <UserLocation
        visible
        showsUserHeadingIndicator
        onUpdate={onUserLocationUpdate}
      />

      {markerCoords && (
        <PointAnnotation
          id="selected-location"
          coordinate={markerCoords as [number, number]}
          draggable
          onDragEnd={onMarkerDragEnd}
        />
      )}
    </MapView>
  );
}
