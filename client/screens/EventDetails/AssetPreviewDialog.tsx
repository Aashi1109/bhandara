import CustomAvatar from "@/components/CustomAvatar";
import { CardWrapper } from "@/components/ui/common-styles";
import { EMediaType } from "@/definitions/enums";
import type { IBaseUser, IMedia } from "@/definitions/types";
import { formatTimeAgo } from "@/utils/date.utils";
import { CloudDownload, ExternalLink, Minus, Plus, RotateCw, X } from "@tamagui/lucide-icons";
import React, { useState } from "react";
import { Slider, styled, Text, XStack, YStack } from "tamagui";
import { useAuth } from "@/contexts/AuthContext";
import { isEmpty } from "@/utils";
import Carousel from "@/components/Carousel";
import { ZoomableImage } from "./ZoomableImage";
import Video from "react-native-video";

interface Props {
  medias: (IMedia & { user?: IBaseUser })[];
  currentSelectedMediaId?: string;
  close: () => void;
}

const IconWrapperCard = styled(CardWrapper, {
  p: "$2",
  rounded: "$2",
  width: "auto",
  cursor: "pointer",
  flexDirection: "row"
});

const STEP_VALUE = 20;

const wrap = (min: number, max: number, v: number) => {
  const rangeSize = max - min;
  return ((((v - min) % rangeSize) + rangeSize) % rangeSize) + min;
};

const AssetPreviewDialog = ({ medias, currentSelectedMediaId, close }: Props) => {
  const { user: currentAuthenticatedUser } = useAuth();
  const [currentSelectedMedia, setCurrentSelectedMedia] = useState(
    () => medias.find((media) => media.id === currentSelectedMediaId) || medias[0]
  );
  const timeAgo = formatTimeAgo(currentSelectedMedia.createdAt);
  const [zoomValue, setZoomValue] = useState(0);
  const mediaUser = currentSelectedMedia.user;

  return (
    <>
      <XStack
        gap={"$2"}
        flex={1}
        justify={"space-between"}
        items={"flex-start"}
      >
        {!isEmpty(mediaUser) && (
          <XStack
            gap={"$2"}
            flex={1}
          >
            <CustomAvatar
              src={mediaUser?.media?.publicUrl || ""}
              alt={mediaUser?.name || ""}
              size={32}
            />
            <YStack>
              <Text fontSize={"$4"}>{mediaUser?.id === currentAuthenticatedUser?.id ? "You" : mediaUser?.name}</Text>
              <Text
                fontSize={"$2"}
                color={"$color10"}
                overflow="hidden"
                numberOfLines={1}
              >
                {`${timeAgo} - ${currentSelectedMedia?.name}`}
              </Text>
            </YStack>
          </XStack>
        )}
        <X
          color={"$color12"}
          size={20}
          cursor="pointer"
          onPress={close}
        />
      </XStack>
      <Carousel
        medias={medias}
        currentSelectedMediaId={currentSelectedMediaId || ""}
        onMediaChange={(media) => {
          setCurrentSelectedMedia(media);
        }}
        renderMedia={(media) => {
          if (media.type === EMediaType.Image) {
            return (
              <ZoomableImage
                uri={media.publicUrl || ""}
                containerStyle={{ width: 500, height: 300, rounded: "$2" }}
                scale={zoomValue / 10 === 0 ? 1 : zoomValue / 10}
              />
            );
          }
          if (media.type === EMediaType.Video) {
            return (
              <Video
                source={{ uri: media.publicUrl }}
                style={{ width: 500, height: 300 }}
                controls
                paused
              />
            );
          }
          return null;
        }}
      />
      {currentSelectedMedia.type === EMediaType.Image && (
        <XStack
          gap={"$2"}
          flex={1}
          justify={"space-between"}
          items={"center"}
          key={"image-controls"}
          enterStyle={{ y: -10, opacity: 0.5 }}
          exitStyle={{ y: 10, opacity: 0.5 }}
          transition={"quickest"}
        >
          <XStack gap={"$2"}>
            <IconWrapperCard onPress={() => setZoomValue(0)}>
              <RotateCw
                color={"$color12"}
                size={16}
              />
            </IconWrapperCard>
            <IconWrapperCard
              gap={"$2"}
              flexDirection="row"
              items={"center"}
            >
              <Minus
                color={"$color12"}
                size={16}
                onPress={() => {
                  setZoomValue((prev) => (prev - STEP_VALUE <= 0 ? 0 : prev - STEP_VALUE));
                }}
              />
              <Slider
                size="$2"
                width={50}
                defaultValue={[zoomValue]}
                value={[zoomValue]}
                max={100}
                step={STEP_VALUE}
                onValueChange={(value) => {
                  setZoomValue(value[0]);
                }}
              >
                <Slider.Track
                  bg={"$color8"}
                  height={2}
                >
                  <Slider.TrackActive bg={"$color12"} />
                </Slider.Track>
                <Slider.Thumb
                  circular
                  index={0}
                  size={16}
                />
              </Slider>
              <Plus
                color={"$color12"}
                size={16}
                onPress={() => {
                  setZoomValue((prev) => (prev + STEP_VALUE >= 100 ? 100 : prev + STEP_VALUE));
                }}
              />
            </IconWrapperCard>
          </XStack>

          <XStack
            gap={"$2"}
            items={"center"}
          >
            <IconWrapperCard gap={"$4"}>
              <CloudDownload
                color={"$color12"}
                size={16}
                cursor="pointer"
                onPress={() => {}}
              />
              <ExternalLink
                color={"$color12"}
                size={16}
                cursor="pointer"
                onPress={() => {}}
              />
            </IconWrapperCard>
          </XStack>
        </XStack>
      )}
    </>
  );
};

export default AssetPreviewDialog;
