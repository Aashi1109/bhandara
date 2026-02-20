import { type ViewProps, Image, XStack, YStack } from "tamagui";

const OvalCard = ({ image, width, height }: { image: string; width: number; height?: number }) => {
  return (
    <Image
      src={image}
      width={width}
      height={height ? height : width * 1.3}
      rounded={10000}
      overflow={"hidden"}
    />
  );
};

const OvalCardStack = ({ config }: { config?: OnBoardingConfig }) => {
  const defaultConfig: OnBoardingConfig = {
    stacks: [
      {
        gap: "$4",
        items: "center",
        justify: "center",
        cards: [
          {
            image: "https://images.unsplash.com/photo-1743527173859-2cf44e80cef8?q=80&w=200&auto=format&fit=crop",
            width: 80
          },
          {
            image: "https://images.unsplash.com/photo-1743527173859-2cf44e80cef8?q=80&w=200&auto=format&fit=crop",
            width: 140
          }
        ]
      },
      {
        gap: "$4",
        flexDirection: "column-reverse",
        items: "center",
        justify: "center",
        cards: [
          {
            image: "https://images.unsplash.com/photo-1743527173859-2cf44e80cef8?q=80&w=200&auto=format&fit=crop",
            width: 80
          },
          {
            image: "https://images.unsplash.com/photo-1743527173859-2cf44e80cef8?q=80&w=200&auto=format&fit=crop",
            width: 140
          }
        ]
      }
    ]
  };

  const _config = config || defaultConfig;

  return (
    <XStack
      gap={"$4"}
      items={"center"}
      justify={"center"}
      height={"70%"}
    >
      {_config.stacks.map((stack, i) => (
        <YStack
          key={i}
          gap={stack.gap ?? "$2"}
          flexDirection={stack.flexDirection || "column"}
          items={stack.items}
          justify={stack.justify}
        >
          {stack.cards.map((card, j) => (
            <OvalCard
              key={j}
              {...card}
            />
          ))}
        </YStack>
      ))}
    </XStack>
  );
};

type OvalCardConfig = {
  image: string;
  width: number;
  height?: number;
};

export type OnBoardingConfig = {
  stacks: {
    gap?: ViewProps["gap"];
    flexDirection?: "column" | "column-reverse";
    items?: ViewProps["items"];
    justify?: ViewProps["justify"];
    cards: OvalCardConfig[];
  }[];
};

export default OvalCardStack;
