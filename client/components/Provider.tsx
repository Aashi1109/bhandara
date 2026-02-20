import { PortalProvider, TamaguiProvider } from "tamagui";
import { SafeAreaProvider } from "react-native-safe-area-context";
import config from "../tamagui.config";

export default function Provider({ children }: { children: React.ReactNode }) {
  return (
    <SafeAreaProvider>
      <PortalProvider shouldAddRootHost>
        <TamaguiProvider
          defaultTheme="dark"
          config={config}
        >
          {children}
        </TamaguiProvider>
      </PortalProvider>
    </SafeAreaProvider>
  );
}
