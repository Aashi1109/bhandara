import { Card, Dialog, Popover, styled, View, YStack, createStyledContext, Text } from "tamagui";
import { SpinningLoader } from "./Loaders";
import { SafeAreaView } from "react-native-safe-area-context";

export const DialogContent = styled(Dialog.Content, {
  bordered: true,
  elevate: true,
  elevation: "$5",
  shadowColor: "$color11",
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.25,
  shadowRadius: 3.84,
  rounded: "$4",
  display: "flex",
  gap: "$4",
  animateOnly: ["transform", "opacity"],
  transition: [
    "quicker",
    {
      opacity: {
        overshootClamping: true
      }
    }
  ],
  enterStyle: { x: 0, y: 20, opacity: 0 },
  exitStyle: { x: 0, y: 10, opacity: 0, scale: 0.95 },
  z: 9999
});

export const DialogTitle = styled(Dialog.Title, {
  fontSize: "$6",
  display: "flex",
  items: "center"
});

export const PopoverContent = styled(Popover.Content, {
  elevate: true,
  bordered: true,
  bg: "$background",
  self: "center",
  rounded: "$6",
  shadowColor: "$color11",
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.25,
  shadowRadius: 3.84,
  elevation: 5,
  overflow: "hidden",
  p: "$4",
  gap: "$2",
  transition: [
    "quick",
    {
      opacity: {
        overshootClamping: true
      }
    }
  ]
});

export const CardWrapper = styled(Card, {
  elevate: true,
  bordered: true,
  bg: "$background",
  self: "center",
  rounded: "$6",
  shadowColor: "$color11",
  shadowOffset: { width: 0, height: 2 },
  shadowOpacity: 0.25,
  shadowRadius: 3.84,
  elevation: 5,
  overflow: "hidden",
  p: "$4",
  width: "100%",
  gap: "$2",

  variants: {
    size: {
      medium: {
        p: "$3",
        rounded: "$4"
      },
      small: {
        p: "$2",
        rounded: "$2"
      }
    } as const
  }
});

export const CircleBgWrapper = styled(View, {
  items: "center",
  justify: "center",
  display: "flex",
  bg: "$color",
  rounded: "$12",
  variants: {
    size: {
      "...size": (size, { tokens }) => {
        return {
          width: (tokens.size as any)[size] || size,
          height: (tokens.size as any)[size] || size
        };
      }
    }
  } as const
});

export const FullSizeLoader = () => (
  <View
    items={"center"}
    justify={"center"}
    flex={1}
    height={"100%"}
    bg={"$background"}
  >
    <SpinningLoader />
  </View>
);
