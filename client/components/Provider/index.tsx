import { useColorScheme } from "react-native";
import { type TamaguiProviderProps, TamaguiProvider } from "tamagui";
import { PortalProvider } from "@tamagui/portal";

const tamaguiConfig = require("@/tamagui.config").default;

const Provider = ({
  children,
  ...rest
}: Omit<TamaguiProviderProps, "config">) => {
  const colorScheme = useColorScheme();
  return (
    <TamaguiProvider
      config={tamaguiConfig}
      defaultTheme={colorScheme!}
      {...rest}
    >
      <PortalProvider>{children}</PortalProvider>
    </TamaguiProvider>
  );
};

export default Provider;
