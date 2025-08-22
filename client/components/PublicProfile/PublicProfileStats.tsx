import React from "react";
import { View, Text, XStack, YStack, Circle, Card, H4 } from "tamagui";
import { Calendar, Clock, Star, Users, Heart } from "@tamagui/lucide-icons";
import { ScrollView } from "react-native";

interface PublicProfileStatsProps {
  stats: {
    eventsHosted: number;
    totalHours: number;
    reviews: number;
    followers?: number;
    likes?: number;
  };
  detailed?: boolean;
}

export default function PublicProfileStats({ stats, detailed = false }: PublicProfileStatsProps) {
  const statItems = [
    {
      icon: Calendar,
      value: stats.eventsHosted,
      label: "Events",
      color: "$purple10",
      bgColor: "$purple3"
    },
    {
      icon: Clock,
      value: `${stats.totalHours}h`,
      label: "Hours",
      color: "$blue10",
      bgColor: "$blue3"
    },
    {
      icon: Star,
      value: stats.reviews,
      label: "Reviews",
      color: "$orange10",
      bgColor: "$orange3"
    },
    ...(stats.followers ? [{
      icon: Users,
      value: formatNumber(stats.followers),
      label: "Followers",
      color: "$green10",
      bgColor: "$green3"
    }] : []),
    ...(stats.likes ? [{
      icon: Heart,
      value: formatNumber(stats.likes),
      label: "Likes",
      color: "$red10",
      bgColor: "$red3"
    }] : [])
  ];

  if (detailed) {
    return (
      <YStack space="$3">
        {statItems.map((stat, index) => {
          const Icon = stat.icon;
          return (
            <Card
              key={index}
              elevate
              bordered
              padding="$4"
              backgroundColor="$color2"
              pressStyle={{ scale: 0.98 }}
              animation="quick"
            >
              <XStack alignItems="center" space="$4">
                <Circle size="$5" backgroundColor={stat.bgColor}>
                  <Icon size={24} color={stat.color} />
                </Circle>
                <YStack flex={1}>
                  <H4 color="$color12" fontWeight="700">{stat.value}</H4>
                  <Text color="$color11" fontSize="$3">{stat.label}</Text>
                </YStack>
              </XStack>
            </Card>
          );
        })}
      </YStack>
    );
  }

  return (
    <ScrollView 
      horizontal 
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={{ paddingHorizontal: 16, paddingVertical: 16 }}
    >
      <XStack space="$3">
        {statItems.map((stat, index) => {
          const Icon = stat.icon;
          return (
            <YStack
              key={index}
              alignItems="center"
              space="$2"
              pressStyle={{ scale: 0.95 }}
              animation="quick"
            >
              <Circle
                size="$6"
                backgroundColor={stat.bgColor}
                pressStyle={{ scale: 0.9 }}
                animation="quick"
              >
                <Icon size={24} color={stat.color} />
              </Circle>
              <Text fontSize="$5" fontWeight="700" color="$color12">
                {stat.value}
              </Text>
              <Text fontSize="$2" color="$color11">
                {stat.label}
              </Text>
            </YStack>
          );
        })}
      </XStack>
    </ScrollView>
  );
}

function formatNumber(num: number): string {
  if (num >= 1000) {
    return (num / 1000).toFixed(1) + "k";
  }
  return num.toString();
}