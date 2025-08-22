import { BackButtonHeader } from "@/components/ui/common-components";
import { SpinningLoader } from "@/components/ui/Loaders";
import { AuthProvider, useAuth } from "@/contexts/AuthContext";
import { SocketProvider } from "@/contexts/Socket";
import { isEmpty } from "@/utils";
import { Redirect, Stack } from "expo-router";
import { View } from "tamagui";

const AuthLayout = ({ children }: { children: React.ReactNode }) => {
  return <AuthProvider>{children}</AuthProvider>;
};

function _Layout() {
  const { isLoading, user, session } = useAuth();

  if (isLoading) {
    return (
      <View
        flex={1}
        height="100%"
        width="100%"
        justify="center"
        items="center"
      >
        <SpinningLoader />
      </View>
    );
  }

  if (!isLoading && isEmpty(user)) {
    return <Redirect href="/onboarding?type=auth" />;
  }

  return (
    <SocketProvider session={`bh_session=${session?.id}`}>
      <Stack>
        <Stack.Screen
          name="(tabs)"
          options={{ headerShown: false, animation: "fade" }}
        />
        <Stack.Screen
          name="new-event"
          options={{
            headerShown: false
          }}
        />
        <Stack.Screen
          name="event/[id]"
          options={{
            headerShown: false
          }}
        />
        <Stack.Screen
          name="profile/[username]"
          options={{
            headerShown: false,
            animation: "slide_from_right"
          }}
        />
      </Stack>
    </SocketProvider>
  );
}

export default function Layout() {
  return (
    <AuthLayout>
      <_Layout />
    </AuthLayout>
  );
}
