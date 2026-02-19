import CustomAvatar from "@/components/CustomAvatar";
import { useAuth } from "@/contexts/AuthContext";
import { Camera, History, Settings, User } from "@tamagui/lucide-icons";
import { Redirect, useLocalSearchParams, useRouter } from "expo-router";
import React, { useState } from "react";
import { SafeAreaView } from "react-native-safe-area-context";
import { Text, View, XStack, YStack } from "tamagui";

import HorizontalTabs from "@/components/CustomTabs";
import InfoTabContent from "./tabs/Info";
import SettingsTabContent from "./tabs/Settings";
import ActivityTabContent from "./tabs/Activity";

import * as ImagePicker from "expo-image-picker";
import { useToastController } from "@tamagui/toast";
import { AVATAR_BUCKET , PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import { updateUser } from "@/common/api/user.action";
import { SpinningLoader } from "@/components/ui/Loaders";
import { formatDateToLongString } from "@/utils/date.utils";
import useSocketListener from "@/hooks/useSocketListener";
import { uploadFile, validateFileSize } from "@/common/utils/file.utils";
import type { EMediaType } from "@/definitions/enums";
import { CustomSafeAreaView } from "@/components/ui/common-components";

const Profile = () => {
  const { user, updateUser: updateUserContext } = useAuth();
  const router = useRouter();
  const toastController = useToastController();
  const { tab } = useLocalSearchParams();
  const defaultTab = tab || "info";
  const [isUploading, setIsUploading] = useState(false);

  useSocketListener(PLATFORM_SOCKET_EVENTS.USER_UPDATED, ({ data }) => {
    if (!data || !user || data.id !== user.id) return;
    updateUserContext(data);
  });

  if (!user) {
    return <Redirect href="/onboarding" />;
  }

  const tabs = [
    {
      label: "Info",
      icon: <User />,
      href: "/profile?tab=info",
      content: <InfoTabContent />
    },
    {
      label: "Settings",
      icon: <Settings />,
      href: "/profile?tab=settings",
      content: <SettingsTabContent />
    },
    {
      label: "My Events",
      icon: <History />,
      href: "/profile?tab=my-events",
      content: <ActivityTabContent />
    }
  ];

  const handleChangeProfilePicture = async () => {
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 1,
      allowsMultipleSelection: false,
      base64: false
    });

    if (result.canceled || !result.assets?.[0]) {
      return;
    }

    try {
      setIsUploading(true);
      const { uri, type, mimeType, fileName, fileSize } = result.assets[0];
      validateFileSize(AVATAR_BUCKET, fileSize);
      const mediaRow = await uploadFile(
        {
          name: fileName!,
          type: type as EMediaType,
          mimeType: mimeType!,
          size: fileSize!,
          uri
        },
        () => {},
        { bucket: AVATAR_BUCKET, pPath: user.id }
      );
      const updateUserResponse = await updateUser(user.id, {
        profilePic: null,
        mediaId: mediaRow.id
      });

      updateUserContext({
        media: updateUserResponse.data?.media
      });

      toastController.show("Profile picture updated");
    } catch (error: any) {
      toastController.show(error?.message || "Failed to update profile picture");
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <CustomSafeAreaView>
      <YStack
        bg="$background"
        width="100%"
        items={"center"}
        p={"$4"}
        gap={"$4"}
      >
        <YStack
          gap={"$4"}
          items={"center"}
        >
          <View
            position="relative"
            height={"$10"}
            width={"$10"}
          >
            <CustomAvatar
              src={user?.profilePic?.url || ""}
              alt={user?.name}
              size={"$10"}
              bordered={false}
            />
            <View
              position="absolute"
              b={0}
              r={0}
              bg="$color"
              rounded="$10"
              p="$2"
              z={10}
              onPress={handleChangeProfilePicture}
              cursor={isUploading ? "not-allowed" : "pointer"}
              pointerEvents={isUploading ? "none" : "auto"}
            >
              {isUploading ? (
                <SpinningLoader color={"$color1"} />
              ) : (
                <Camera
                  size={16}
                  color="$color1"
                />
              )}
            </View>
          </View>
          <Text text={"center"}>{user?.name}</Text>
          <Text
            text={"center"}
            fontWeight={"300"}
            fontSize={"$3"}
            color={"$color11"}
          >
            Member since {formatDateToLongString(user?.createdAt.toString())}
          </Text>
        </YStack>

        <XStack gap={"$4"}>
          <HorizontalTabs
            tabs={tabs}
            defaultValue={defaultTab as string}
            cb={(value: string) => {
              router.push(`/profile?tab=${value}`);
            }}
          />
        </XStack>
      </YStack>
    </CustomSafeAreaView>
  );
};

export default Profile;
