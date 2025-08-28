import React from "react";
import { View, Text, YStack, XStack, Image, Button, H1, H2, Paragraph, Circle, getTokens } from "tamagui";
import { ChevronLeft, MoreHorizontal, Award } from "@tamagui/lucide-icons";
import { BlurView } from "expo-blur";
import { Dimensions, ImageBackground } from "react-native";
import CustomAvatar from "@/components/CustomAvatar";

const { width: screenWidth, height: screenHeight } = Dimensions.get("window");

interface PublicProfileHeaderProps {
  user: any;
  onBack: () => void;
}

export default function PublicProfileHeader({ user, onBack }: PublicProfileHeaderProps) {
  const tokens = getTokens();

  return (
    <View
      height={screenHeight * 0.4}
      position="relative"
    >
      {/* Background Image with Blur */}
      <ImageBackground
        source={{ uri: user.coverImage || user.profilePic }}
        style={{
          position: "absolute",
          width: screenWidth,
          height: "100%"
        }}
        blurRadius={20}
      >
        {/* <LinearGradient
          colors={["rgba(0,0,0,0.3)", "rgba(0,0,0,0.7)"]}
          start={[0, 0]}
          end={[0, 1]}
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 0,
            b: 0
          }}
        /> */}
      </ImageBackground>

      {/* Top Navigation */}
      <XStack
        position="absolute"
        t="$12"
        l="$4"
        r="$4"
        z={10}
        justify="space-between"
        items="center"
      >
        <Button
          size="$3"
          circular
          bg="rgba(255,255,255,0.2)"
          borderWidth={0}
          onPress={onBack}
          pressStyle={{ scale: 0.9 }}
          animation="quick"
        >
          <ChevronLeft
            size={24}
            color="white"
          />
        </Button>

        <Button
          size="$3"
          circular
          bg="rgba(255,255,255,0.2)"
          borderWidth={0}
          pressStyle={{ scale: 0.9 }}
          animation="quick"
        >
          <MoreHorizontal
            size={24}
            color="white"
          />
        </Button>
      </XStack>

      {/* Profile Content */}
      <YStack
        flex={1}
        justify="center"
        items="center"
        pt="$12"
        pb="$6"
        px="$4"
      >
        {/* Avatar with Badge */}
        <View
          position="relative"
          mb="$4"
        >
          <Circle
            size="$12"
            overflow="hidden"
            borderWidth={3}
            borderColor="rgba(255,255,255,0.5)"
            bg="rgba(255,255,255,0.1)"
          >
            <Image
              source={{ uri: user.profilePic }}
              width="100%"
              height="100%"
              resizeMode="cover"
            />
          </Circle>

          {/* Experience Badge */}
          {user.experience && (
            <View
              position="absolute"
              b={-5}
              self="center"
              bg="$blue10"
              px="$3"
              py="$1"
              rounded="$10"
              flexDirection="row"
              items="center"
              gap="$1"
            >
              <Award
                size={14}
                color="white"
              />
              <Text
                color="white"
                fontSize="$1"
                fontWeight="600"
              >
                {user.experience}
              </Text>
            </View>
          )}
        </View>

        {/* Name and Bio */}
        <H1
          color="white"
          text="center"
          fontSize="$9"
          fontWeight="700"
          textShadowColor="rgba(0,0,0,0.5)"
          textShadowOffset={{ width: 0, height: 2 }}
          textShadowRadius={4}
        >
          {user.name}
        </H1>

        <Paragraph
          color="rgba(255,255,255,0.9)"
          text="center"
          fontSize="$4"
          mt="$2"
          textShadowColor="rgba(0,0,0,0.5)"
          textShadowOffset={{ width: 0, height: 1 }}
          textShadowRadius={2}
        >
          {user.bio}
        </Paragraph>
      </YStack>
    </View>
  );
}
