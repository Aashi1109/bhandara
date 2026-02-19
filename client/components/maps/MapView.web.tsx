import config from "@/config";
import mapboxgl from "mapbox-gl";

import "mapbox-gl/dist/mapbox-gl.css";
import { useEffect, useRef, type RefObject } from "react";
import { View } from "tamagui";

const MapViewComponent = ({
  initialLocation,
  consumerRef,
  searchRef
}: {
  initialLocation?: [number, number];
  consumerRef: RefObject<any>;
  searchRef: RefObject<{ setCallBack: (callback: (result: any) => void) => void }>;
}) => {
  const mapRef = useRef<mapboxgl.Map>();
  const mapContainerRef = useRef<any>();
  const markerRef = useRef<mapboxgl.Marker>();
  const currentLocationRef = useRef<[number, number] | undefined>(initialLocation);

  const _flyTo = (lngLat: [number, number]) => {
    if (!mapRef.current) return;

    const currentZoom = mapRef.current.getZoom();

    mapRef.current?.flyTo({
      center: lngLat,
      zoom: currentZoom < 5 ? 10 : currentZoom, // keep current zoom if its less than 10
      speed: 1.2, // animation speed
      curve: 1.42, // animation curve (lower is faster)
      essential: true
    });
  };

  useEffect(() => {
    const coordinates = initialLocation || [77.46183, 22.76583];
    mapboxgl.accessToken = config.mapbox.accessToken;
    mapRef.current = new mapboxgl.Map({
      container: mapContainerRef.current,
      center: coordinates, // default center of India,
      zoom: 4.2
    });

    const marker = new mapboxgl.Marker({ draggable: true }).setLngLat(coordinates).addTo(mapRef.current);
    markerRef.current = marker;
    mapRef.current.addControl(new mapboxgl.NavigationControl());

    const geoLocateControl = new mapboxgl.GeolocateControl({
      positionOptions: {
        enableHighAccuracy: true
      },
      // When active the map will receive updates to the device's location as it changes.
      trackUserLocation: true,
      // Draw an arrow next to the location dot to indicate which direction the device is heading.
      showUserHeading: true
    });
    mapRef.current.addControl(geoLocateControl);

    geoLocateControl.on("geolocate", (e) => {
      currentLocationRef.current = [e.coords.longitude, e.coords.latitude];
      markerRef.current?.setLngLat([e.coords.longitude, e.coords.latitude]);
      executeConsumerCallbacks({ "map:geolocate": { longitude: e.coords.longitude, latitude: e.coords.latitude } });
    });

    mapRef.current.on("click", (e) => {
      const coords = [e.lngLat.lng, e.lngLat.lat] as [number, number];
      _flyTo(coords);
      markerRef.current?.setLngLat(coords);
      executeConsumerCallbacks({ "marker:change": { longitude: e.lngLat.lng, latitude: e.lngLat.lat } });
    });

    markerRef.current?.on("dragend", (e) => {
      const lngLat = e.target.getLngLat();
      _flyTo([lngLat.lng, lngLat.lat]);
      executeConsumerCallbacks({ "marker:dragend": { longitude: lngLat.lng, latitude: lngLat.lat } });
    });

    mapRef.current.on("load", () => {
      if (initialLocation) {
        _flyTo(initialLocation);
      }
    });

    return () => {
      mapRef.current?.remove();
      markerRef.current?.remove();
    };
  }, []);

  useEffect(() => {
    if (initialLocation) {
      _flyTo(initialLocation);
    }
    mapRef.current?.on("load", () => {
      if (initialLocation) {
        markerRef.current?.setLngLat(initialLocation);
      }
    });
  }, [initialLocation]);

  const handleSearchResultSelect = (result: any) => {
    const coords = result.geometry.coordinates;
    _flyTo(coords);
    markerRef.current?.setLngLat(coords);
  };

  useEffect(() => {
    searchRef.current?.setCallBack(handleSearchResultSelect);
  }, [searchRef.current]);

  const executeConsumerCallbacks = (data: Record<string, any>) => {
    Object.values(consumerRef.current).forEach((value) => {
      if (typeof value === "function") {
        value(data);
      }
    });
  };

  return (
    <View
      position="relative"
      width={"100%"}
      flex={1}
    >
      <View
        id="map-container"
        width={"100%"}
        height={"100%"}
        ref={mapContainerRef}
      />
    </View>
  );
};

export default MapViewComponent;
