import React from "react";
import { Avatar, Text, View } from "tamagui";

const CustomAvatar = ({
  size = 40,
  src,
  alt,
  bordered = true,
  fallbackGenerator,
  onPress
}: {
  size?: number | string;
  src: string;
  alt: string;
  bordered?: boolean;
  fallbackGenerator?: (alt: string) => string;
  onPress?: () => void;
}) => {
  const extraStyles = bordered
    ? {
        borderColor: "$color11",
        borderWidth: "$0.5",
        p: "$1"
      }
    : {};

  const _size = bordered ? (size as any) - 5 : size;
  return (
    <View
      rounded={"$12"}
      items={"center"}
      justify={"center"}
      width={size}
      height={size}
      z={10}
      {...(extraStyles as any)}
      onPress={onPress}
      cursor={onPress ? "pointer" : "default"}
    >
      <Avatar
        circular
        size={_size as any}
        group={true}
      >
        <Avatar.Image
          height={_size}
          width={_size}
          accessibilityLabel={alt}
          src={src}
          $group-hover={{
            scale: 1.05
          }}
          transition={"transform 0.2s ease-in-out"}
        />
        <Avatar.Fallback
          backgroundColor="$accent11"
          justify={"center"}
          items={"center"}
        >
          <Text
            fontSize={(_size as number) * 0.4}
            color={"$color12"}
          >
            {fallbackGenerator ? fallbackGenerator(alt) : alt.charAt(0)}
          </Text>
        </Avatar.Fallback>
      </Avatar>
    </View>
  );
};

export default CustomAvatar;
