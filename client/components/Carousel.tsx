import React, { useState } from "react";
import { type ViewProps, AnimatePresence, styled, useTheme, View } from "tamagui";
import { CircleBgWrapper } from "./ui/common-styles";
import { ChevronLeft, ChevronRight } from "@tamagui/lucide-icons";
import type { IMedia } from "@/definitions/types";

const GalleryItem = styled(View, {
  position: "absolute",
  overflow: "hidden",
  z: 1,
  x: 0,
  opacity: 1,
  variants: {
    going: {
      ":number": (going) => ({
        enterStyle: {
          x: going > 0 ? 500 : -500,
          opacity: 0
        },
        exitStyle: {
          zIndex: 0,
          x: going < 0 ? 500 : -500,
          opacity: 0
        }
      })
    }
  } as const
});

interface CarouselProps {
  medias: IMedia[];
  currentSelectedMediaId?: string;
  renderMedia: (media: IMedia) => React.ReactNode;
  styles?: ViewProps;
  onMediaChange?: (media: IMedia) => void;
}

const Carousel = ({ medias, currentSelectedMediaId, renderMedia, styles, onMediaChange }: CarouselProps) => {
  const theme = useTheme();
  const [[mediaIndex, going], setMediaIndex] = useState(() => {
    const index = medias.findIndex((f) => f.id === currentSelectedMediaId);
    if (index !== -1) return [index, 0];
    else return [0, 0];
  });

  const paginate = (going: number) => {
    setMediaIndex([mediaIndex + going, going]);
    onMediaChange?.(medias[mediaIndex + going]);
  };

  const getNumericHeight = (height?: any) => {
    let _height;
    if (typeof height === "number") _height = height;
    if (typeof height === "string") _height = theme?.size?.[height as keyof typeof theme.size];
    return _height || 300;
  };

  const currentSelectedMedia = medias[mediaIndex];
  const isLeftButtonDisabled = mediaIndex === 0;
  const isRightButtonDisabled = mediaIndex === medias.length - 1;

  const _width = styles?.width || 500;
  const _height = getNumericHeight(styles?.height);

  return (
    <View
      position="relative"
      {...styles}
      width={_width}
      height={_height}
      group
    >
      <AnimatePresence
        initial={false}
        custom={{ going }}
      >
        <GalleryItem
          flexDirection="row"
          justify={"center"}
          key={mediaIndex}
          transition="quicker"
          going={going}
          width={_width}
          height={_height}
        >
          {renderMedia(currentSelectedMedia)}
        </GalleryItem>
      </AnimatePresence>

      {/* navigation button */}
      <CircleBgWrapper
        bg={"$accent11"}
        p={"$2"}
        t={_height / 2 - 19} // button wrapper size 38/2 = 19
        l={0}
        position="absolute"
        display="none"
        hoverStyle={{ x: -5, bg: "$accent10" }}
        $group-hover={{ display: isLeftButtonDisabled ? "none" : "flex" }}
        transition={"medium"}
        cursor={"pointer"}
        onPress={() => paginate(-1)}
        z={10}
      >
        <ChevronLeft />
      </CircleBgWrapper>
      <CircleBgWrapper
        bg={"$accent11"}
        p={"$2"}
        t={_height / 2 - 19}
        r={0}
        position="absolute"
        display="none"
        hoverStyle={{ x: 5, bg: "$accent10" }}
        $group-hover={{ display: isRightButtonDisabled ? "none" : "flex" }}
        transition={"medium"}
        cursor={"pointer"}
        onPress={() => paginate(1)}
        z={10}
      >
        <ChevronRight />
      </CircleBgWrapper>
    </View>
  );
};

export default Carousel;
