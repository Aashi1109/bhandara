import type { IAddress } from "@/definitions/types";
import React, { useEffect, useImperativeHandle, useState, type RefObject } from "react";
import { Text, useDebounce, View, XStack, YStack } from "tamagui";
import { InputGroup } from "../Form";
import { type FieldError, useForm } from "react-hook-form";
import { isEmpty, startCase } from "@/utils";
import { FilledButton } from "../ui/Buttons";
import { MapPin } from "@tamagui/lucide-icons";
import { getAddressFromCoordinates } from "@/common/api/mapbox";
import { useToastController } from "@tamagui/toast";
import { SpinningLoader } from "../ui/Loaders";
import { setNavState } from "@/lib/navigationStore";
import { router } from "expo-router";

interface AddressFormProps {
  existingData?: IAddress;
  onSaveCallback?: (values: IAddress) => void;
  mapViewRef: RefObject<any>;
  pushDataKeyRef: RefObject<string>;
}

const AddressForm = ({ existingData, onSaveCallback, mapViewRef, pushDataKeyRef }: AddressFormProps) => {
  const {
    control,
    handleSubmit,
    reset,
    formState: { errors }
  } = useForm<IAddress>({
    defaultValues: existingData
  });

  const [isLocationLoading, setIsLocationLoading] = useState(false);
  const toastController = useToastController();

  const _onSubmit = async (values: IAddress) => {
    try {
      onSaveCallback?.(values);
      router.back();
      router.setParams({
        dataKey: pushDataKeyRef.current
      });
    } catch (error: any) {
      toastController.show(error?.message || "Error updating location");
    }
  };

  const _getSetLocationFromCoordinates = async (coordinates: { latitude: number; longitude: number }) => {
    setIsLocationLoading(true);
    try {
      const res = await getAddressFromCoordinates({
        latitude: coordinates.latitude,
        longitude: coordinates.longitude
      });

      if (!res || isEmpty(res)) throw new Error("No address found");
      toastController.show("Address updated successfully");
      if (pushDataKeyRef.current) {
        setNavState(pushDataKeyRef.current, res);
      }
      reset(res);
    } catch (error: any) {
      toastController.show(error?.message || "Error updating location");
    } finally {
      setIsLocationLoading(false);
    }
  };

  const debouncedGetSetLocationFromCoordinates = useDebounce(_getSetLocationFromCoordinates, 500);

  useEffect(() => {
    if (!isEmpty(existingData)) {
      reset(existingData);
    }
  }, [existingData]);

  useImperativeHandle(mapViewRef, () => ({
    ...mapViewRef.current,
    eventListener: (e: Record<string, any>) => {
      const eventName = Object.keys(e)[0];
      const eventData = e[eventName];
      if (["marker:dragend", "marker:change", "map:geolocate"].includes(eventName)) {
        // fetch new address from selected coordinates
        debouncedGetSetLocationFromCoordinates(eventData);
      }
    }
  }));

  const validationRules = {
    address: {
      required: "Address is required"
    },
    street: {
      required: "Street is required"
    },
    building: {
      required: false
    },
    postcode: {
      required: "Postcode is required",
      pattern: {
        value: /^[A-Z0-9\s-]+$/i,
        message: "Invalid postcode format"
      }
    },
    city: {
      required: "City is required"
    },
    district: {
      required: "District is required"
    },
    state: {
      required: "State is required"
    },
    country: {
      required: "Country is required"
    },
    landmark: {
      required: false
    }
  };

  const renderAddressField = (label: string, error: FieldError | undefined) => {
    const rightLabel = validationRules[label as keyof typeof validationRules]?.required ? "Required" : "Optional";
    return (
      <InputGroup
        label={startCase(label)}
        control={control}
        rules={validationRules[label as keyof typeof validationRules]}
        name={label}
        placeHolder={startCase(label)}
        error={error}
        rightLabel={rightLabel}
      />
    );
  };

  if (isLocationLoading) {
    return (
      <View
        justify="center"
        items="center"
      >
        <SpinningLoader />
      </View>
    );
  }

  return (
    <YStack
      overflow="hidden"
      gap={"$4"}
      flex={1}
    >
      <XStack
        items={"center"}
        justify={"space-between"}
      >
        <MapPin size={20} />
        <Text
          fontSize={"$1"}
          color={"$red10"}
          px={"$2"}
          py={"$1"}
          bg={"$red5"}
          rounded={"$4"}
          cursor={"pointer"}
          onPress={() => {
            reset(existingData);
          }}
        >
          Reset
        </Text>
      </XStack>

      <YStack
        gap={"$4"}
        flex={1}
        overflowY="scroll"
        p={"$1"}
      >
        {renderAddressField("street", errors.street)}
        {renderAddressField("building", errors.building)}
        {renderAddressField("landmark", errors.landmark)}

        <XStack
          gap={"$4"}
          flex={1}
          shrink={0}
        >
          {renderAddressField("postcode", errors.postcode)}
          {renderAddressField("city", errors.city)}
        </XStack>
        <XStack
          gap={"$4"}
          flex={1}
          shrink={0}
        >
          {renderAddressField("district", errors.district)}
          {renderAddressField("state", errors.state)}
        </XStack>
        {renderAddressField("country", errors.country)}
      </YStack>
      <FilledButton onPress={handleSubmit(_onSubmit)}>Save</FilledButton>
    </YStack>
  );
};

export default AddressForm;
