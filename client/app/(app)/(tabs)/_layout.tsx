import TabsHeader from "@/components/TabsHeader";
import { House, Plus, UserRound } from "@tamagui/lucide-icons";
import { BlurView } from "expo-blur";
import { Tabs } from "expo-router";
import { Platform } from "react-native";
import { getTokenValue, useTheme, View } from "tamagui";

export default function TabLayout() {
  const theme = useTheme();

  const paddingX = getTokenValue("$2", "space");
  const marginBottom = getTokenValue("$3", "space");

  return (
    <Tabs
      screenOptions={{
        header: (props) => <TabsHeader {...props} />,
        animation: "fade",
        tabBarActiveTintColor: theme.color.val,
        tabBarInactiveTintColor: theme.color10.val,
        tabBarStyle: {
          backgroundColor: theme.color3.val,
          borderTopColor: theme.borderColor.val,
          paddingTop: paddingX,
          paddingBottom: paddingX,
          height: "auto",
          borderTopWidth: 0,
          backdropFilter: "blur(10px)",
          borderRadius: 100,
          width: 320,
          marginHorizontal: "auto",
          marginBottom,
          position: "absolute",
        },
        tabBarBackground: () => {
          return (
            <BlurView
              intensity={80}
              tint={Platform.OS === "ios" ? "light" : "dark"}
              style={{
                borderTopLeftRadius: 20,
                borderTopRightRadius: 20,
                overflow: "hidden",
                position: "absolute",
              }}
            />
          );
        },
      }}
    >
      <Tabs.Screen
        name="home"
        options={{
          title: "Home",
          tabBarIcon: ({ color }) => <House size={16} color={color as any} />,
        }}
      />
      <Tabs.Screen
        name="_new-event"
        options={{
          tabBarLabelStyle: {
            display: "none",
          },
          tabBarIconStyle: {
            height: "100%",
          },
          href: "/(app)/new-event",
          tabBarIcon: ({}) => (
            <View width={40} height={40} bg={"$color12"} display="flex" justify="center" items="center" rounded={"$4"}>
              <Plus size={20} color={theme.color1.val as any} />
            </View>
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarIcon: ({ color }) => <UserRound size={16} color={color as any} />,
        }}
      />
    </Tabs>
  );
}
