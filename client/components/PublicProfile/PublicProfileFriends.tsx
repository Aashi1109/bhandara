import React from "react";
import { View, Text, XStack, YStack, Circle, Image, Button, Card, H3 } from "tamagui";
import { Plus, Users } from "@tamagui/lucide-icons";
import { ScrollView } from "react-native";

interface Friend {
  id: string;
  name: string;
  avatar: string;
}

interface PublicProfileFriendsProps {
  friends: Friend[];
}

export default function PublicProfileFriends({ friends }: PublicProfileFriendsProps) {
  if (!friends || friends.length === 0) {
    return null;
  }

  return (
    <View px="$4" py="$4">
      <Card elevate bordered padding="$4" backgroundColor="$color2">
        <YStack space="$3">
          <XStack alignItems="center" justifyContent="space-between">
            <XStack alignItems="center" space="$2">
              <Users size={20} color="$color11" />
              <H3>Collaborators</H3>
            </XStack>
            <Text color="$color11" fontSize="$3">
              {friends.length} people
            </Text>
          </XStack>

          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            <XStack space="$3">
              {friends.map((friend) => (
                <YStack
                  key={friend.id}
                  alignItems="center"
                  space="$2"
                  pressStyle={{ scale: 0.95 }}
                  animation="quick"
                >
                  <Circle
                    size="$6"
                    overflow="hidden"
                    borderWidth={2}
                    borderColor="$color5"
                  >
                    <Image
                      source={{ uri: friend.avatar }}
                      width="100%"
                      height="100%"
                      resizeMode="cover"
                    />
                  </Circle>
                  <Text fontSize="$1" color="$color11" numberOfLines={1}>
                    {friend.name}
                  </Text>
                </YStack>
              ))}

              {/* Add Collaborator Button */}
              <YStack
                alignItems="center"
                space="$2"
                pressStyle={{ scale: 0.95 }}
                animation="quick"
              >
                <Circle
                  size="$6"
                  backgroundColor="$color4"
                  borderWidth={2}
                  borderColor="$color5"
                  borderStyle="dashed"
                  alignItems="center"
                  justifyContent="center"
                >
                  <Plus size={24} color="$color11" />
                </Circle>
                <Text fontSize="$1" color="$color11">
                  Add
                </Text>
              </YStack>
            </XStack>
          </ScrollView>
        </YStack>
      </Card>
    </View>
  );
}