import type { IBaseUser, ITag } from "@/definitions/types";
import { type XStackProps, H4, Text, Theme, useTheme, View, XStack, YStack } from "tamagui";
import CustomAvatar from "../CustomAvatar";
import ProfileAvatarPreview from "./ProfileAvatarPreview";
import { Fragment } from "react";
import { useRouter } from "expo-router";
import { ArrowLeft } from "@tamagui/lucide-icons";
import CustomTooltip from "../CustomTooltip";
import { CardWrapper } from "./common-styles";
import { Badge } from "./Badge";
import { SafeAreaView } from "react-native-safe-area-context";

export const TagPreviewTooltip = ({ tag }: { tag: ITag }) => {
  return (
    <CardWrapper size={"small"}>
      <Text fontSize={"$3"}>
        {tag.icon} {tag.name}
      </Text>
      <Text fontSize={"$2"}>{tag.description}</Text>
    </CardWrapper>
  );
};

export const UserCluster = ({
  users,
  maxLimit = 3,
  avatarSize = 30,
  containerStyles
}: {
  users: IBaseUser[];
  maxLimit?: number;
  avatarSize?: number;
  containerStyles?: XStackProps;
}) => {
  const _users = users.slice(0, maxLimit);
  const remainingUsers = users.length - maxLimit;

  if (remainingUsers > 0) {
    _users.push({
      id: "remaining",
      name: `+${remainingUsers}`,
      profilePic: {
        publicUrl: ""
      }
    } as any);
  }
  return (
    <XStack
      position={"relative"}
      {...containerStyles}
      height={avatarSize}
    >
      {_users.map((user, index) => {
        const _Wrapper = remainingUsers < 0 ? ProfileAvatarPreview : Fragment;
        return (
          <View
            l={25 * index + index}
            position={"absolute"}
            z={index}
            rounded={"$12"}
            bg={"$background"}
            pl={index !== 0 ? "$1" : 0}
            cursor={"pointer"}
            key={user.id}
          >
            <_Wrapper user={user}>
              <CustomAvatar
                size={avatarSize}
                src={user.profilePic?.url || ""}
                alt={user.name}
                fallbackGenerator={(alt) => {
                  if (user.id === "remaining") {
                    return alt;
                  }
                  return alt.charAt(0);
                }}
              />
            </_Wrapper>
          </View>
        );
      })}
    </XStack>
  );
};

type HalfCircleBadgeProps = {
  percentage: number; // 0 to 100
  size?: number;
};

export function CircularFillIndicator({ percentage, size = 40 }: HalfCircleBadgeProps) {
  // Clamp between 0 and 100
  const fillPercent = Math.max(20, Math.min(100, percentage * 100));
  const fillRatio = fillPercent / 100;

  return (
    <View
      width={size}
      height={size}
      rounded={size}
      bg="$color12"
      justify="center"
      items="center"
    >
      <View
        width={size * 0.8}
        height={size * 0.8}
        rounded={size * 0.8}
        overflow="hidden"
        bg="$accent8"
        position="relative"
        opacity={0.8}
      >
        <View
          position="absolute"
          b={0}
          l={0}
          r={0}
          height={`${fillRatio * 100}%`}
          bg="$green11"
          z={1}
        />
      </View>
    </View>
  );
}

export const IdentityCard = ({
  imageUrl,
  subtitle,
  title,
  imageAlt,
  size = 40,
  onlyImage = false
}: {
  imageUrl: string;
  title: string;
  subtitle: string;
  imageAlt?: string;
  size?: number;
  onlyImage?: boolean;
}) => (
  <XStack
    items={"center"}
    gap={"$2"}
    cursor={"pointer"}
  >
    <CustomAvatar
      size={size}
      src={imageUrl}
      alt={imageAlt ?? title}
    />
    {!onlyImage && (
      <YStack gap={"$1"}>
        <Text
          fontSize={0.45 * size}
          fontWeight={"bold"}
        >
          {title}
        </Text>
        <Text
          fontSize={0.35 * size}
          color={"$color11"}
        >
          {subtitle}
        </Text>
      </YStack>
    )}
  </XStack>
);

export const BackButtonHeader = ({
  title,
  navigateTo,
  arrowCb,
  children
}: {
  title: string;
  navigateTo?: any;
  arrowCb?: () => null | void;
  children?: React.ReactNode;
}) => {
  const router = useRouter();

  return (
    <XStack
      items={"center"}
      gap={"$2"}
      position={"relative"}
      height={"$3"}
    >
      <View
        width={"$3"}
        height={"$3"}
        bg={"$color4"}
        rounded={"$4"}
        items={"center"}
        justify={"center"}
        cursor={"pointer"}
        position={"absolute"}
        l={0}
        z={1}
        hoverStyle={{
          transform: "translateX(-2px)",
          transition: "transform 0.2s ease-in-out"
        }}
      >
        <ArrowLeft
          size={24}
          color={"$accent1"}
          cursor={"pointer"}
          onPress={() => {
            if (navigateTo) router.navigate(navigateTo);
            if (arrowCb) arrowCb?.();
          }}
        />
      </View>

      <H4
        text={"center"}
        flex={1}
      >
        {title}
      </H4>

      {children && (
        <View
          height={"$3"}
          position={"absolute"}
          r={0}
          t={0}
          z={1}
        >
          {children}
        </View>
      )}
    </XStack>
  );
};

export const TagListing = ({ tags }: { tags: ITag[] }) => {
  return (
    <XStack
      flexWrap="wrap"
      gap={"$2"}
    >
      {tags?.map((tag: ITag) => (
        <CustomTooltip
          trigger={
            <Badge cursor="pointer">
              <Badge.Text fontSize={"$3"}>{tag.name}</Badge.Text>
            </Badge>
          }
          key={tag.id}
          tooltipConfig={{ placement: "top" }}
        >
          <TagPreviewTooltip tag={tag} />
        </CustomTooltip>
      ))}
    </XStack>
  );
};

export const CustomSafeAreaView = ({ children }: { children: React.ReactNode }) => {
  const theme = useTheme();
  console.log("theme", theme);
  return <SafeAreaView style={{ flex: 1, backgroundColor: theme.background.val }}>{children}</SafeAreaView>;
};
