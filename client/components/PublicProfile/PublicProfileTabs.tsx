import React from "react";
import { View, Text, XStack, Button, ScrollView } from "tamagui";
import { Home, BarChart3, Camera, Calendar } from "@tamagui/lucide-icons";

interface PublicProfileTabsProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
}

export default function PublicProfileTabs({ activeTab, onTabChange }: PublicProfileTabsProps) {
  const tabs = [
    { id: "hello", label: "Hello", icon: Home },
    { id: "stats", label: "Stats", icon: BarChart3 },
    { id: "photos", label: "Photos", icon: Camera },
    { id: "schedule", label: "Schedule", icon: Calendar }
  ];

  return (
    <View px="$4" py="$2">
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <XStack space="$2">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            
            return (
              <Button
                key={tab.id}
                size="$3"
                onPress={() => onTabChange(tab.id)}
                backgroundColor={isActive ? "$color12" : "$color4"}
                borderRadius="$10"
                pressStyle={{ scale: 0.95 }}
                animation="quick"
                borderWidth={0}
              >
                <XStack alignItems="center" space="$2">
                  <Icon 
                    size={18} 
                    color={isActive ? "$color1" : "$color11"}
                  />
                  <Text 
                    color={isActive ? "$color1" : "$color11"}
                    fontWeight={isActive ? "600" : "400"}
                    fontSize="$3"
                  >
                    {tab.label}
                  </Text>
                </XStack>
              </Button>
            );
          })}
        </XStack>
      </ScrollView>
    </View>
  );
}