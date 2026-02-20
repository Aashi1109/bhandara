import { useState } from "react";
import { Button, H2, Input, Paragraph, Separator, XStack, YStack, AnimatePresence } from "tamagui";
import { Github, ChevronDown } from "@tamagui/lucide-icons";
import GoogleIcon from "@/assets/svg/GoogleIcon";
import Label from "@/components/ui/Label";
import { Controller, useForm } from "react-hook-form";
import AuthForm from "./Form";

// Simple Google SVG icon component

function Auth({ isLogin }: { isLogin?: boolean }) {
  const [isSignUp, setIsSignUp] = useState(!isLogin);

  return (
    <YStack
      width={400}
      m="auto"
      p="$4"
      gap="$5"
      transition="bouncy"
      enterStyle={{ height: 0 }}
      animateOnly={["height"]}
      background={"#111111"}
      rounded={"$6"}
      borderWidth={1}
      borderColor={"#222222"}
    >
      {/* Header */}
      <YStack gap="$2">
        <H2 text="center" transition="quick" enterStyle={{ opacity: 0, scale: 0.9 }} exitStyle={{ opacity: 0, scale: 0.9 }}>
          {isSignUp ? "Create your account" : "Sign in"}
        </H2>
        <Paragraph text="center" color="$color10" transition="quick" enterStyle={{ opacity: 0, y: -10 }} exitStyle={{ opacity: 0, y: 10 }}>
          {isSignUp ? "Welcome! Please fill in the details to get started." : "Welcome back! Please sign in to continue"}
        </Paragraph>
      </YStack>

      {/* Social Login */}
      <XStack gap="$2">
        <Button flex={1} icon={<Github size="$1" />} borderWidth={1}>
          GitHub
        </Button>
        <Button flex={1} icon={<GoogleIcon />} borderWidth={1}>
          Google
        </Button>
      </XStack>

      <XStack items="center" gap="$2">
        <Separator />
        <Paragraph size="$2" color="$color8">
          or
        </Paragraph>
        <Separator />
      </XStack>

      {/* Form Fields */}
      <AuthForm isSignUp={isSignUp} cb={() => {}} />

      {/* Form Toggle */}
      <XStack justify="center" gap="$2" transition="quick" enterStyle={{ opacity: 0 }} exitStyle={{ opacity: 0 }}>
        <Paragraph color="$color10">{isSignUp ? "Already have an account?" : "Don't have an account?"}</Paragraph>
        <Paragraph unstyled cursor="pointer" color="$blue10" textDecorationLine="underline" hoverStyle={{ opacity: 0.9 }} onPress={() => setIsSignUp(!isSignUp)}>
          {isSignUp ? "Sign in" : "Sign up"}
        </Paragraph>
      </XStack>
    </YStack>
  );
}

export default Auth;
