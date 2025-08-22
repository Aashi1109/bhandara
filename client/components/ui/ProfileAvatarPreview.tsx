import { IBaseUser } from "@/definitions/types";
import React from "react";
import { YStack, XStack, Text, Card, Separator, Theme, Popover } from "tamagui";
import CustomAvatar from "../CustomAvatar";
import { OutlineButton } from "./Buttons";
import { formatDateToLongString } from "@/utils/date.utils";
import { useAuth } from "@/contexts/AuthContext";
import { CardWrapper, PopoverContent } from "./common-styles";
import { PopoverWrapper } from "../PopoverWrapper";
import { useRouter } from "expo-router";

const Preview = ({ user, children }: { user: IBaseUser; children?: React.ReactNode }) => {
  const { user: _authenticatedUser } = useAuth();
  const username = user.username ? `@${user.username}` : "";
  const router = useRouter();

  return (
    <CardWrapper
      width={"auto"}
      p={0}
      minW={250}
    >
      <XStack
        gap="$3"
        items="center"
        p="$5"
      >
        <CustomAvatar
          size={40}
          src={user.profilePic?.url || ""}
          alt={user.name}
        />
        <YStack>
          <Text
            fontSize={"$8"}
            fontWeight={"bold"}
          >
            {user.name}
          </Text>
          {username && <Text fontSize={"$3"}>{username}</Text>}
        </YStack>
      </XStack>
      <YStack
        gap="$4"
        p="$5"
        pt={0}
      >
        <YStack gap="$2">
          <Text fontSize={"$3"}>Email</Text>
          <Text
            fontSize={"$3"}
            color={"$color11"}
          >
            {user.email}
          </Text>
        </YStack>
        <YStack gap="$2">
          <Text fontSize={"$3"}>Joined on</Text>
          <Text
            fontSize={"$3"}
            color={"$color11"}
          >
            {formatDateToLongString(user.createdAt)}
          </Text>
        </YStack>
        {user?.bio && (
          <YStack gap="$2">
            <Text
              fontSize={"$3"}
              color={"$color11"}
            >
              Bio
            </Text>
            <Text fontSize={"$3"}>{user.bio}</Text>
          </YStack>
        )}
      </YStack>
      {children && (
        <>
          <Separator />
          <YStack
            p="$5"
            gap="$2"
          >
            {children}
          </YStack>
        </>
      )}
      <YStack
        p="$5"
        pt={0}
        gap="$2"
      >
        {user.id === _authenticatedUser?.id ? (
          <Popover.Close>
            <OutlineButton
              size={"medium"}
              width={"auto"}
              onPress={() => router.push("/profile?")}
            >
              Edit Profile
            </OutlineButton>
          </Popover.Close>
        ) : (
          <Popover.Close>
            <OutlineButton
              size={"medium"}
              width={"auto"}
              onPress={() => router.push(`/profile/${user.username || user.id}`)}
            >
              View Profile
            </OutlineButton>
          </Popover.Close>
        )}
      </YStack>
    </CardWrapper>
  );
};

const ProfileAvatarPreview = ({
  user,
  children,
  extraMeta
}: {
  user: IBaseUser;
  children: React.ReactNode;
  extraMeta?: React.ReactNode;
}) => (
  <PopoverWrapper
    trigger={children}
    hoverable
  >
    <PopoverContent
      z={1000}
      borderWidth={0}
      p={0}
      rounded={"$6"}
    >
      <Theme name={"dark"}>
        <Preview user={user}>{extraMeta}</Preview>
      </Theme>
    </PopoverContent>
  </PopoverWrapper>
);

export default ProfileAvatarPreview;
