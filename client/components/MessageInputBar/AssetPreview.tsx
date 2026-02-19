import { CardWrapper } from "@/components/ui/common-styles";
import React, { useRef } from "react";
import { Image, View } from "tamagui";
import Video, { type VideoRef } from "react-native-video";
import { EMediaType } from "@/definitions/enums";

interface IProps {
  type: EMediaType;
  file?: string;
  publicLink?: string;
  size?: number;
}

const AssetPreview = ({ type, file, publicLink, size = 50 }: IProps) => {
  const videoRef = useRef<VideoRef>(null);

  const RenderPreview = () => {
    switch (type) {
      case EMediaType.Image:
        if (!file && !publicLink) return null;
        return (
          <Image
            src={file ? file : ({ uri: publicLink || "" } as any)}
            height={size - 1}
            width={size - 1}
          />
        );
      case EMediaType.Video:
        if (!publicLink) return null;
        return (
          <Video
            source={{ uri: publicLink }}
            ref={videoRef}
            style={{
              width: size - 1,
              position: "relative",
              height: size - 1
            }}
          />
        );
    }
  };

  return (
    <CardWrapper
      rounded={"$3"}
      p={0}
      height={size}
      width={size}
    >
      {RenderPreview()}
    </CardWrapper>
  );
};

export default AssetPreview;
