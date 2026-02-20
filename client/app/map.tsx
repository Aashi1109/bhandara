import AddressForm from "@/components/maps/AddressForm";
import MapViewComponent from "@/components/maps/MapView";
import Search from "@/components/maps/Search";
import type { IAddress } from "@/definitions/types";
import { getUUIDv4 } from "@/helpers";
import { getNavState } from "@/lib/navigationStore";
import { ArrowLeft } from "@tamagui/lucide-icons";
import { useLocalSearchParams, useRouter } from "expo-router";
import React, { memo, useEffect, useRef, useState } from "react";
import { Sheet, XStack, YStack } from "tamagui";

const SheetContents = memo(({ initialData, mapViewRef, pushDataKeyRef }: any) => {
  return (
    <AddressForm
      mapViewRef={mapViewRef}
      existingData={initialData}
      pushDataKeyRef={pushDataKeyRef}
    />
  );
});

const Map = () => {
  const router = useRouter();
  const searchRef = useRef<any>();
  const consumerRef = useRef<any>();
  const pushDataKeyRef = useRef(getUUIDv4());

  const { dataKey } = useLocalSearchParams();

  const snapPoints = ["80%", "30%"];
  const [position, setPosition] = useState(snapPoints.length - 1);

  const [initialData, setInitialData] = useState<IAddress | null>(null);

  useEffect(() => {
    const selectedLocationInfo = getNavState(dataKey as string);
    setInitialData(selectedLocationInfo);
  }, [dataKey]);

  const initialLocation =
    initialData?.latitude && initialData?.longitude ? [initialData?.longitude, initialData?.latitude] : undefined;

  return (
    <>
      <YStack
        gap={"$4"}
        width={"100%"}
        flex={1}
        p={"$4"}
        position="relative"
      >
        <XStack
          items={"center"}
          gap={"$3"}
          position="static"
        >
          <ArrowLeft
            size={24}
            color={"$accent1"}
            cursor={"pointer"}
            onPress={() => {
              router.back();
              router.setParams({
                dataKey: pushDataKeyRef.current
              });
            }}
          />
          <Search
            ref={searchRef}
            onSearchResultSelect={() => {}}
            onMinimizedCheckClick={setInitialData}
          />
        </XStack>
        <MapViewComponent
          consumerRef={consumerRef}
          initialLocation={initialLocation}
          searchRef={searchRef}
        />
      </YStack>

      <Sheet
        modal={true}
        open={true}
        zIndex={100_000}
        transition={"quickest"}
        dismissOnOverlayPress={false}
        dismissOnSnapToBottom={false}
        snapPoints={snapPoints}
        position={position}
        onPositionChange={setPosition}
        snapPointsMode="mixed"
      >
        <Sheet.Handle />
        <Sheet.Frame
          p="$4"
          py={"$6"}
          justify="flex-start"
          items="center"
          gap="$5"
          bg={"$accent12"}
          mx={"auto"}
        >
          <SheetContents {...{ initialData, mapViewRef: consumerRef, pushDataKeyRef }} />
        </Sheet.Frame>
      </Sheet>
    </>
  );
};

export default Map;
