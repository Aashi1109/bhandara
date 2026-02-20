import type { IAddress } from "@/definitions/types";
import { askForLocation, haversineDistanceInM } from "@/utils/location";
import { useToastController } from "@tamagui/toast";
import { useEffect, useState } from "react";
import type * as Location from "expo-location";
import { getStaticMapImageUrl } from "@/common/api/mapbox";
import { CardWrapper, CircleBgWrapper } from "./ui/common-styles";
import { Image, Text, XStack, YStack } from "tamagui";
import { Building, Compass, Crosshair, Landmark, MapPin, Navigation, Signpost } from "@tamagui/lucide-icons";
import { formatDistance } from "@/helpers";
import { FilledButton } from "./ui/Buttons";
import { Linking } from "react-native";

const MapPreviewCard = (location: IAddress) => {
  const [currentLocation, setCurrentLocation] = useState<Location.LocationObjectCoords | null>(null);
  const toastController = useToastController();

  useEffect(() => {
    const _func = async () => {
      await askForLocation(
        ({ coords }) => {
          setCurrentLocation(coords);
        },
        () => toastController.show("Permission denied for location")
      );
    };

    _func();
  }, []);

  const _getMapUrl = () => {
    if (location.latitude && location.longitude) {
      const staticMapUrl = getStaticMapImageUrl({
        latitude: location.latitude,
        longitude: location.longitude,
        markerConfig: {
          color: "fa0505",
          size: "l"
        },
        zoom: 15
      });
      return staticMapUrl;
    }
  };

  const staticMapURL = _getMapUrl();
  const distanceAway = currentLocation
    ? haversineDistanceInM(
        { latitude: currentLocation.latitude, longitude: currentLocation.longitude },
        { latitude: location.latitude, longitude: location.longitude }
      )
    : "-";

  const _distanceAwayLabel = distanceAway !== "-" ? formatDistance(distanceAway) : distanceAway;

  return (
    <CardWrapper
      display="flex"
      flexDirection="column"
      gap={"$4"}
      items="center"
      width={"100%"}
    >
      <XStack
        gap={"$2"}
        items="center"
        justify="flex-start"
        width={"100%"}
      >
        <CircleBgWrapper size={"$2"}>
          <MapPin
            size={16}
            color={"$color10"}
          />
        </CircleBgWrapper>
        <Text
          fontSize={"$5"}
          numberOfLines={1}
          textOverflow="ellipsis"
        >{`${location.street}, ${location.city}, ${location.state} ${location.postcode}`}</Text>
      </XStack>

      <XStack
        gap={"$4"}
        flex={1}
        justify="flex-start"
        width={"100%"}
      >
        <Image
          src={staticMapURL}
          width={130}
          height={130}
          rounded={"$4"}
          hoverStyle={{
            scale: 1.05
          }}
        />
        <YStack
          flex={1}
          gap={"$2"}
          justify={"flex-start"}
          height={"100%"}
        >
          {(location.building || location?.place) && (
            <XStack
              gap={"$2"}
              items="center"
            >
              <Building
                size={16}
                color={"$color10"}
              />
              <Text>{location.building || location.place}</Text>
            </XStack>
          )}
          {location.street && (
            <XStack
              gap={"$2"}
              items="center"
            >
              <Signpost
                size={16}
                color={"$color10"}
              />
              <Text
                fontSize={"$2"}
                color={"$color10"}
              >
                {location.street}
              </Text>
            </XStack>
          )}
          {location.landmark && (
            <XStack
              gap={"$2"}
              items="center"
            >
              <Landmark
                size={16}
                color={"$color10"}
              />
              <Text fontSize={"$3"}>{location.landmark}</Text>
            </XStack>
          )}
          <XStack
            gap={"$2"}
            items="center"
          >
            <Crosshair
              size={16}
              color={"$color10"}
            />
            <Text
              color={"$color10"}
              fontSize={"$2"}
            >
              {location.latitude}, {location.longitude}
            </Text>
          </XStack>

          <XStack
            gap={"$2"}
            items="center"
          >
            <Navigation
              size={16}
              color={"$color10"}
            />

            <Text
              color={"$color10"}
              fontSize={"$2"}
            >
              {_distanceAwayLabel} away
            </Text>
          </XStack>
          <FilledButton
            rounded={"$4"}
            width={"min-content"}
            onPress={() => {
              Linking.openURL(
                `https://www.google.com/maps/dir/?api=1&destination=${location.latitude},${location.longitude}`
              );
            }}
            size={"small"}
            icon={<Compass size={16} />}
          >
            Get Directions
          </FilledButton>
        </YStack>
      </XStack>
    </CardWrapper>
  );
};

export default MapPreviewCard;
