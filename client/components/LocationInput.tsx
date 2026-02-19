import { MapPin, RotateCw , SquareArrowOutUpRight } from "@tamagui/lucide-icons";
import React, { useState } from "react";
import { InputGroup } from "./Form";
import { Text, Tooltip, useDebounce } from "tamagui";
import { getAddressFromCoordinates } from "@/common/api/mapbox";
import { useToastController } from "@tamagui/toast";
import { type Control, type FieldErrors, UseFormSetValue } from "react-hook-form";
import { SpinningLoader } from "./ui/Loaders";
import type * as Location from "expo-location";
import { getUUIDv4 } from "@/helpers";
import { setNavState } from "@/lib/navigationStore";
import { useRouter } from "expo-router";
import { isEmpty } from "@/utils";
import type { IAddress } from "@/definitions/types";
import CustomTooltip from "./CustomTooltip";
import { askForLocation } from "@/utils/location";
import { CardWrapper } from "./ui/common-styles";

type PartialAddress = Partial<IAddress> & { _location?: string };

interface IProps {
  existingLocation?: PartialAddress;
  setValue: (value: IAddress & { _location: string }) => void;
  control: Control<any>;
  errors: FieldErrors<IAddress & { _location: string }>;
  isViewOnly?: boolean;
}

const LocationInput = ({ existingLocation, setValue, control, errors, isViewOnly }: IProps) => {
  const [isLocationLoading, setIsLocationLoading] = useState<boolean>(false);
  const toastController = useToastController();
  const router = useRouter();

  const _getSetLocationFromCoordinates = async (coordinates: { latitude: number; longitude: number }) => {
    setIsLocationLoading(true);
    try {
      const res = await getAddressFromCoordinates({
        latitude: coordinates.latitude,
        longitude: coordinates.longitude
      });

      if (!res) return;

      setValue({
        ...res,
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        _location: res.address
      });
    } catch (error: any) {
      toastController.show(error?.message || "Error getting location");
    } finally {
      setIsLocationLoading(false);
    }
  };
  const debouncedGetSetLocationFromCoordinates = useDebounce(_getSetLocationFromCoordinates, 300);

  async function onLocationGet(location: Location.LocationObject) {
    // if location is already set and didn't change, do nothing
    if (
      existingLocation?.latitude === location.coords.latitude &&
      existingLocation?.longitude === location.coords.longitude
    )
      return;

    debouncedGetSetLocationFromCoordinates.cancel();
    debouncedGetSetLocationFromCoordinates({
      latitude: location.coords.latitude,
      longitude: location.coords.longitude
    });
  }

  const handleEditLocation = () => {
    if (!isEmpty(existingLocation)) {
      const locationKey = getUUIDv4();
      setNavState(locationKey, existingLocation);

      router.push({
        pathname: "/map",
        params: {
          dataKey: locationKey
        }
      });
    }
  };

  const handleLocationGetPress = async () => {
    await askForLocation(onLocationGet, (data: any) => {
      toastController.show(data?.message || "Permission denied for location");
    });
  };

  return (
    <InputGroup
      control={control}
      name="_location"
      label="Location"
      placeHolder="Use your current location"
      rules={{ required: "Location is required" }}
      error={errors._location?.message}
      containerProps={{
        onPress: existingLocation?._location ? undefined : handleLocationGetPress,
        cursor: isViewOnly ? "initial" : "pointer",
        pointerEvents: isViewOnly ? "none" : "auto"
      }}
      inputProps={{
        editable: false
      }}
      iconAfter={
        isLocationLoading ? (
          <SpinningLoader />
        ) : existingLocation?._location && !isViewOnly ? (
          <>
            <CustomTooltip
              trigger={
                <RotateCw
                  size={16}
                  onPress={handleLocationGetPress}
                />
              }
              tooltipConfig={{
                delay: 200
              }}
            >
              <CardWrapper
                rounded={"$3"}
                p={"$2"}
              >
                <Text fontSize={"$2"}>Refresh location</Text>
              </CardWrapper>
            </CustomTooltip>

            <CustomTooltip
              trigger={
                <SquareArrowOutUpRight
                  size={16}
                  onPress={handleEditLocation}
                />
              }
              tooltipConfig={{
                delay: 200
              }}
            >
              <CardWrapper
                rounded={"$3"}
                p={"$2"}
              >
                <Text fontSize={"$2"}>Edit location</Text>
              </CardWrapper>
            </CustomTooltip>
          </>
        ) : (
          <MapPin size={20} />
        )
      }
    />
  );
};

export default LocationInput;
