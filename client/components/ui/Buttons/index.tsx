import { Button, styled } from "tamagui";

const baseButtonConfig = {
  transition: "lazy",
  transitionDuration: "100ms",
  rounded: "$12",
  pt: "$2.5",
  pb: "$2.5",
  variants: {
    danger: {
      true: {
        bg: "$red6",
        color: "$red11",
        hoverStyle: { bg: "$red7", borderColor: "$red7" },
      },
    },
    disabled: {
      true: {
        opacity: 0.5,
        cursor: "not-allowed",
      },
      false: {
        opacity: 1,
        cursor: "pointer",
      },
    },
    size: {
      medium: {
        fontSize: "$4",
        px: "$3",
        py: "$1.5",
        height: "min-content",
      },
      small: {
        fontSize: "$3",
        px: "$2",
        py: "$0",
        height: "min-content",
      },
    },
  } as const,
} as const;

// Tamagui Button styled config type omits `color`/`rounded`; they work at runtime.
export const FilledButton = styled(Button, {
  name: "FilledButton",
  hoverStyle: { bg: "$accent2", borderColor: "$accent2" },
  height: "auto",
  width: "100%",
} as const);

export const OutlineButton = styled(Button, {
  ...baseButtonConfig,
  name: "OutlinedButton",
  variant: "outlined",
} as const);
