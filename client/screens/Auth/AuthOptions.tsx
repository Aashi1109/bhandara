import React, { useEffect, useState } from "react";
import * as WebBrowser from "expo-web-browser";
import { makeRedirectUri, useAuthRequest } from "expo-auth-session";
import type { IBaseUser } from "@/definitions/types";
import { useToastController } from "@tamagui/toast";
import config from "@/config";
import { useRouter } from "expo-router";
import { Platform } from "react-native";
import { signInWithIdToken } from "@/common/api/auth.action";
import { Button, H3, Text } from "tamagui";
import { FilledButton, OutlineButton } from "@/components/ui/Buttons";
import GoogleIcon from "@/assets/svg/GoogleIcon";
import { SpinningLoader } from "@/components/ui/Loaders";
import { Mail } from "@tamagui/lucide-icons";
import { EApplicableStage } from "../OnBoarding/enum";

WebBrowser.maybeCompleteAuthSession();

const AuthOptions = ({
  setExistingAuthData,
  setApplicableStages,
}: {
  setExistingAuthData: (data: { isUserComingFromSocialAuth: boolean; user?: IBaseUser; hasOnboarded?: boolean }) => void;
  setApplicableStages: (formStage: EApplicableStage) => void;
}) => {
  const toastController = useToastController();
  const router = useRouter();
  const [isSocialAuthenticationInProgress, setIsSocialAuthenticationInProgress] = useState(false);

  const discovery = {
    authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
    tokenEndpoint: "https://oauth2.googleapis.com/token",
  };

  const redirectUri = makeRedirectUri({});
  const clientIds = {
    web: config.google.webClientId,
    ios: config.google.iosClientId,
    android: config.google.androidClientId,
  };

  const clientId = clientIds[Platform.OS as keyof typeof clientIds] || config.google.webClientId;

  const [request, response, promptAsync] = useAuthRequest(
    {
      clientId,
      scopes: ["https://www.googleapis.com/auth/userinfo.profile", "https://www.googleapis.com/auth/userinfo.email"],
      redirectUri: redirectUri,
    },
    discovery,
  );

  useEffect(() => {
    const handleGoogleAuth = async (response: any) => {
      try {
        if (!response) return;
        if (response?.type === "dismissed") {
          throw new Error("Google sign in cancelled");
        }

        if (response?.type !== "success") throw new Error(response?.error?.message || "Error signing in with Google");

        const { code } = response?.params || {};

        if (!code) throw new Error("No code received from Google");

        const res = await signInWithIdToken(code, request?.codeVerifier || "", redirectUri);
        const { session, user } = res.data;

        if (!session || !user) throw new Error("No session or user received from Google");

        toastController.show("Signed in successfully");
        if (user.meta?.hasOnboarded) return router.push("/home");

        setExistingAuthData({ isUserComingFromSocialAuth: true, user, hasOnboarded: !!user.meta?.hasOnboarded });
      } catch (error: any) {
        toastController.show(error?.message || "Error signing in with Google");
      } finally {
        setIsSocialAuthenticationInProgress(false);
      }
    };
    handleGoogleAuth(response);
  }, [response]);

  return (
    <>
      <H3>Get Started</H3>
      <Text fontSize={"$2"} fontWeight={"normal"} color={"$color9"}>
        Discover, book, and track events seamlessly with calendar integration and personalized event curation
      </Text>

      <FilledButton
        ml={"auto"}
        mr={"auto"}
        icon={<GoogleIcon size={20} />}
        disabled={isSocialAuthenticationInProgress}
        onPress={() => {
          setIsSocialAuthenticationInProgress(true);
          promptAsync();
        }}
        iconAfter={isSocialAuthenticationInProgress ? <SpinningLoader /> : undefined}
      >
        <Text fontSize={"$2"} color={"$accent12"}>
          Sign up with Google
        </Text>
      </FilledButton>
      {!isSocialAuthenticationInProgress && (
        <OutlineButton
          icon={<Mail size={20} />}
          onPress={() => {
            setApplicableStages(EApplicableStage.NewUser);
          }}
        >
          <Text fontSize={"$2"}>Sign up with Email</Text>
        </OutlineButton>
      )}

      <Text
        fontSize={"$2"}
        fontWeight={100}
        color={"$accent9"}
        mt={"$6"}
        mx={"auto"}
        cursor={isSocialAuthenticationInProgress ? "not-allowed" : "pointer"}
        pointerEvents={isSocialAuthenticationInProgress ? "none" : "auto"}
      >
        Already have an account?{" "}
        <Text
          fontSize={"$2"}
          fontWeight={"100"}
          cursor={"pointer"}
          onPress={() => {
            setApplicableStages(EApplicableStage.EmailExists);
          }}
        >
          Login
        </Text>
      </Text>
    </>
  );
};

export default AuthOptions;
