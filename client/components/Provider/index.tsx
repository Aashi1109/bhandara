import { useColorScheme } from "react-native";
import { type TamaguiProviderProps, TamaguiProvider } from "tamagui";
import tamaguiConfig from "@/tamagui.config";

const Provider = ({
  children,
  ...rest
}: Omit<TamaguiProviderProps, "config">) => {
  const colorScheme = useColorScheme();
  return (
    <TamaguiProvider
      config={tamaguiConfig}
      defaultTheme={colorScheme ?? "dark"}
      {...rest}
    >
      {children}
    </TamaguiProvider>
  );
};

export default Provider;
