import React from "react";
import { View, Image, Pressable } from "tamagui";
import { Play } from "@tamagui/lucide-icons";
import { Dimensions } from "react-native";

const { width: screenWidth } = Dimensions.get("window");
const imageSize = (screenWidth - 48) / 2; // 2 columns with padding

interface PublicProfileGalleryProps {
  gallery: Array<{
    id: string;
    url: string;
    type: "image" | "video";
  }>;
  onImagePress: (image: any) => void;
}

export default function PublicProfileGallery({ gallery, onImagePress }: PublicProfileGalleryProps) {
  // Split gallery into two columns for masonry effect
  const leftColumn = gallery.filter((_, index) => index % 2 === 0);
  const rightColumn = gallery.filter((_, index) => index % 2 === 1);

  const renderGalleryItem = (item: any, index: number, isLeft: boolean) => {
    // Vary heights for masonry effect
    const heights = [200, 250, 180, 220, 240];
    const height = heights[index % heights.length];

    return (
      <Pressable
        key={item.id}
        onPress={() => onImagePress(item)}
        style={{ marginBottom: 8 }}
      >
        <View
          width={imageSize}
          height={height}
          borderRadius="$4"
          overflow="hidden"
          position="relative"
          backgroundColor="$color3"
          pressStyle={{ scale: 0.95 }}
          animation="quick"
        >
          <Image
            source={{ uri: item.url }}
            width="100%"
            height="100%"
            resizeMode="cover"
          />
          
          {/* Video overlay */}
          {item.type === "video" && (
            <View
              position="absolute"
              top={0}
              left={0}
              right={0}
              bottom={0}
              backgroundColor="rgba(0,0,0,0.3)"
              alignItems="center"
              justifyContent="center"
            >
              <View
                backgroundColor="rgba(255,255,255,0.9)"
                width="$5"
                height="$5"
                borderRadius="$10"
                alignItems="center"
                justifyContent="center"
              >
                <Play size={24} color="black" fill="black" />
              </View>
            </View>
          )}
        </View>
      </Pressable>
    );
  };

  return (
    <View px="$4">
      <View flexDirection="row" justifyContent="space-between">
        <View flex={1} pr="$1">
          {leftColumn.map((item, index) => renderGalleryItem(item, index, true))}
        </View>
        <View flex={1} pl="$1">
          {rightColumn.map((item, index) => renderGalleryItem(item, index, false))}
        </View>
      </View>
    </View>
  );
}