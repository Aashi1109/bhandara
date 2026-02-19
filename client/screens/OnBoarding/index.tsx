import { FilledButton } from "@/components/ui/Buttons";
import { ArrowLeft } from "@tamagui/lucide-icons";
import React, { memo, useEffect, useMemo, useState } from "react";
import { debounce, H3, Sheet, Text, View, XStack, YStack } from "tamagui";
import { useForm } from "react-hook-form";
import { getUserByEmail, updateUser } from "@/common/api/user.action";

import { useToastController } from "@tamagui/toast";

import type { IAddress } from "@/definitions/types";
import InterestSelection from "./InterestSelection";
import OvalCardStack from "./OvalCard";

import { InputGroup } from "@/components/Form";
import { useRouter , useLocalSearchParams } from "expo-router";
import { isEmpty } from "@/utils";
import { getNavState } from "@/lib/navigationStore";
import { SpinningLoader } from "@/components/ui/Loaders";
import { loginWithEmailAndPassword, signupWithEmailAndPassword } from "@/common/api/auth.action";

import { EGender, EOnboardingStages } from "@/definitions/enums";
import AuthOptions from "../Auth/AuthOptions";
import { APPLICABLE_STAGES_MAP, getStageLevelFields, ONBOARDING_STAGES_TEXT } from "./constants";
import type { IFormData } from "./type";
import ProfileSetup from "./ProfileSetup";
import PreGetStartedContent from "./PreGetStartedContent";
import { EApplicableStage } from "./enum";

const GetStartedContents = ({
  setPosition,
  position
}: {
  setPosition: (position: number) => void;
  position: number;
}) => {
  const { type } = useLocalSearchParams();
  const [showAuthOptions, setShowAuthOptions] = useState(() => type !== "new");
  const [isLoading, setIsLoading] = useState(false);
  const toastController = useToastController();
  const [newUser, setNewUser] = useState<any>(null);
  const router = useRouter();

  const params = useLocalSearchParams();

  const {
    control,
    handleSubmit,
    watch,
    formState: { errors },
    setError,
    setValue,
    reset
  } = useForm<IFormData>({
    mode: "all"
  });

  const allValues = watch();

  const [authStage, setAuthStage] = useState<EOnboardingStages>(EOnboardingStages.EmailVerification);
  const [isUserComingFromSocialAuth, setIsUserComingFromSocialAuth] = useState<boolean>(false);
  const [applicableStage, setApplicableStage] = useState<EApplicableStage>(EApplicableStage.EmailExists);

  const showMiniProgressBars =
    [EApplicableStage.NewUser, EApplicableStage.NotOnboarded].includes(applicableStage) &&
    authStage !== EOnboardingStages.EmailVerification;

  const stageFields = getStageLevelFields(authStage, isUserComingFromSocialAuth);

  useEffect(() => {
    if (params.dataKey) {
      const location = getNavState(params.dataKey as string);
      if (!isEmpty(location)) {
        setValue("location", location);
        setValue("_location", location.address);
      }
    }
  }, [params.dataKey]);

  const stageHandlers = {
    [EOnboardingStages.EmailVerification]: async ({ data }: { data: IFormData }) => {
      try {
        await getUserByEmail(data.email);
        setAuthStage(EOnboardingStages.Login);
      } catch (error: any) {
        if (error.error?.status === 404) {
          setAuthStage(EOnboardingStages.BasicInfo);
          setApplicableStage(EApplicableStage.NewUser);
        } else {
          toastController.show(error?.error?.message || "Error checking email");
        }
      }
    },
    [EOnboardingStages.Login]: async ({ data }: { data: IFormData }) => {
      try {
        await loginWithEmailAndPassword(data.email, data.password);
        // do something with the new user
      } catch (error: any) {
        toastController.show(error?.error?.message || "Error logging in");
      }
    },
    [EOnboardingStages.BasicInfo]: async ({ data }: { data: IFormData }) => {
      try {
        if (!newUser) {
          const res = await signupWithEmailAndPassword({
            name: `${data.firstName} ${data.lastName}`,
            email: data.email,
            password: data.password
          });
          if (isEmpty(res.data.user)) {
            toastController.show("Not able to create user");
            return;
          }
          setNewUser(res.data.user);
        }
        setAuthStage(EOnboardingStages.ProfileSetup);
      } catch (error: any) {
        toastController.show(error?.error?.message || "Error signing up");
      }
    },
    [EOnboardingStages.ProfileSetup]: async () => {
      setAuthStage(EOnboardingStages.InterestSelection);
    },
    [EOnboardingStages.InterestSelection]: async ({ data }: { data: IFormData }) => {
      // save and update all the data
      try {
        const updateData = {
          address: data.location,
          username: data.username,
          profilePic: data.profilePic,
          interests: { added: data.interests?.map((tag) => tag.id) },
          gender: data.gender,
          hasOnboarded: true
        };
        await updateUser(newUser.id, updateData);
        toastController.show("Onboarding completed successfully");
        router.push("/home");
      } catch (error: any) {
        toastController.show(error?.error?.message || "Error saving data");
      }
    }
  };

  const stageHandler = useMemo(() => debounce(stageHandlers[authStage], 300), [authStage]);

  const handleContinueClick = async (data: IFormData) => {
    try {
      setIsLoading(true);
      await stageHandler({ data });
    } catch (error) {
    } finally {
      setIsLoading(false);
    }
  };

  const isContinueButtonDisabled =
    !!Object.keys(errors).length ||
    isLoading ||
    !stageFields?.every((field: string) => !!allValues[field as keyof IFormData]);

  const { stages, skippableStages } = APPLICABLE_STAGES_MAP[applicableStage];

  const isFirstStage = stages[0] === authStage;
  const isCurrentStageSkippable = (skippableStages as EOnboardingStages[]).includes(authStage);

  const handleSetExistingDataAuth = ({
    isUserComingFromSocialAuth,
    user,
    hasOnboarded
  }: {
    isUserComingFromSocialAuth?: boolean;
    user?: any;
    hasOnboarded?: boolean;
  }) => {
    if (user) {
      setNewUser(user);
    }

    setIsUserComingFromSocialAuth(!!isUserComingFromSocialAuth);

    if (!hasOnboarded) {
      setPosition(0);
      setAuthStage(EOnboardingStages.BasicInfo);
      setApplicableStage(EApplicableStage.NotOnboarded);

      if (user) {
        const { name, address, email, gender, profilePic, username } = user;
        const [firstName, lastName] = name.split(" ");
        const resetObj: Record<string, any> = {
          firstName,
          lastName,
          _location: address?.address,
          location: address as IAddress,
          email,
          username
        };

        if (gender && [EGender.Male, EGender.Female].includes(gender as EGender)) resetObj.gender = gender;
        if (profilePic && profilePic.url) resetObj.profilePic = profilePic;
        reset(resetObj);
      }
    }
  };

  const showForm = position === 0;

  if (showForm)
    return (
      <YStack
        gap={"$4"}
        width={"100%"}
        flex={1}
      >
        {(isFirstStage ? !newUser : true) && (
          <ArrowLeft
            size={24}
            color={"$accent1"}
            cursor={"pointer"}
            onPress={() => {
              setAuthStage((prev) => {
                const currentIndex = stages.indexOf(prev);
                if (currentIndex === 0) {
                  setPosition(1);
                  return EOnboardingStages.EmailVerification;
                }
                return stages[currentIndex - 1];
              });
            }}
          />
        )}
        <YStack gap={"$2"}>
          <H3>{ONBOARDING_STAGES_TEXT[authStage]?.title}</H3>
          <Text
            fontSize={"$2"}
            fontWeight={"100"}
            color={"$accent9"}
          >
            {ONBOARDING_STAGES_TEXT[authStage]?.description}
          </Text>
        </YStack>

        {authStage === EOnboardingStages.BasicInfo && (
          <XStack
            gap="$4"
            animation={"quick"}
            enterStyle={{ opacity: 0, y: 15 }}
            exitStyle={{ opacity: 0, y: -15 }}
            key="signup-fields"
            width="100%"
            height={"auto"}
          >
            <InputGroup
              control={control}
              rules={{
                required: "First name is required",
                minLength: { value: 2, message: "First name must be at least 2 characters" },
                pattern: { value: /^[A-Za-z]+$/, message: "Please enter valid characters" }
              }}
              error={errors.firstName}
              placeHolder="First name"
              name="firstName"
              label="First name"
              rightLabel="Required"
            />
            <InputGroup
              control={control}
              rules={{
                required: "Last name is required",
                minLength: { value: 2, message: "Last name must be at least 2 characters" },
                pattern: { value: /^[A-Za-z]+$/, message: "Please enter valid characters" }
              }}
              error={errors.lastName}
              placeHolder="Last name"
              name="lastName"
              label="Last name"
              rightLabel="Required"
            />
          </XStack>
        )}

        {[EOnboardingStages.EmailVerification, EOnboardingStages.BasicInfo, EOnboardingStages.Login].includes(
          authStage
        ) && (
          <>
            <InputGroup
              control={control}
              name="email"
              rules={{
                required: "Email is required",
                pattern: {
                  value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                  message: "Please enter a valid email address"
                }
              }}
              error={errors.email}
              placeHolder="Email address"
              label="Email address"
              rightLabel="Required"
              inputProps={{
                keyboardType: "email-address",
                disabled: authStage !== EOnboardingStages.EmailVerification
              }}
            />
          </>
        )}

        {[EOnboardingStages.Login, EOnboardingStages.BasicInfo].includes(authStage) && !isUserComingFromSocialAuth && (
          <InputGroup
            name="password"
            control={control}
            rules={{
              required: "Password is required",
              minLength: {
                value: 8,
                message: "Password must be at least 8 characters"
              },
              pattern: {
                value: /^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$/,
                message: "Password must contain at least one letter and one number"
              }
            }}
            error={errors.password}
            placeHolder="Password"
            label="Password"
            rightLabel="Required"
            inputProps={{
              secureTextEntry: true
            }}
          />
        )}
        {authStage === EOnboardingStages.BasicInfo && !isUserComingFromSocialAuth && (
          <InputGroup
            control={control}
            name="verifyPassword"
            rules={{
              required: "Verify password is required",
              validate: (value: string | null) => {
                if (value !== allValues.password) {
                  return "Passwords do not match";
                }
                return true;
              }
            }}
            error={errors.verifyPassword}
            placeHolder="Re-enter your password"
            label="Verify password"
            rightLabel="Required"
          />
        )}

        {authStage === EOnboardingStages.ProfileSetup && (
          <ProfileSetup
            allValues={allValues}
            setValue={setValue}
            control={control}
            errors={errors}
            setError={setError}
          />
        )}

        {authStage === EOnboardingStages.InterestSelection && (
          <InterestSelection
            cb={(tags) => {
              setValue("interests", tags);
            }}
          />
        )}

        <XStack
          mt={"auto"}
          width={"100%"}
          justify={"space-between"}
          items={"center"}
        >
          {showMiniProgressBars && (
            <XStack gap={"$2"}>
              {stages.map((stage, i) => {
                const hasError = stageFields?.some((field: string) => !!errors[field as keyof IFormData]);
                return (
                  <View
                    key={i}
                    onPress={handleSubmit(() => setAuthStage(stage))}
                    bg={hasError ? "$red1" : authStage !== stage ? "$accent10" : "$accent1"}
                    rounded={10000}
                    width={authStage === stage ? "$3" : "$0.75"}
                    height={"$0.75"}
                    cursor={"pointer"}
                    animation={"quick"}
                  />
                );
              })}
            </XStack>
          )}
          <FilledButton
            onPress={handleSubmit(handleContinueClick)}
            animation="quick"
            disabled={isContinueButtonDisabled}
            opacity={isContinueButtonDisabled ? 0.5 : 1}
            cursor={isContinueButtonDisabled ? "not-allowed" : "pointer"}
            pointerEvents={isContinueButtonDisabled ? "none" : "auto"}
            items={"center"}
            iconAfter={isLoading ? <SpinningLoader /> : undefined}
            width={!showMiniProgressBars ? "100%" : "auto"}
          >
            {authStage !== EOnboardingStages.InterestSelection ? "Continue" : "Finish"}
          </FilledButton>
        </XStack>
      </YStack>
    );

  return (
    <YStack
      gap={"$3"}
      width={"100%"}
      maxW={350}
      justify={"space-between"}
      height={250}
    >
      {showAuthOptions ? (
        <AuthOptions
          setExistingAuthData={handleSetExistingDataAuth}
          setApplicableStages={(applicableStage) => {
            setPosition(0);
            setApplicableStage(applicableStage);
          }}
        />
      ) : (
        <PreGetStartedContent setShowAuthOptions={setShowAuthOptions} />
      )}
    </YStack>
  );
};

const SheetContents = memo(({ setPosition, position }: any) => {
  return (
    <YStack
      gap="$2"
      items={"center"}
      width={"100%"}
      flex={1}
    >
      <GetStartedContents {...{ setPosition, position }} />
    </YStack>
  );
});

const OnBoarding = () => {
  const [position, setPosition] = useState(1);

  return (
    <>
      <OvalCardStack />
      <Sheet
        modal={false}
        open={true}
        zIndex={100_000}
        animation={"quick"}
        dismissOnOverlayPress={false}
        dismissOnSnapToBottom={false}
        snapPoints={["90%", 300]}
        onPositionChange={setPosition}
        position={position}
        snapPointsMode="mixed"
        disableDrag={true}
      >
        <Sheet.Overlay
          animation="quick"
          enterStyle={{ opacity: 0 }}
          exitStyle={{ opacity: 0 }}
          bg={"transparent"}
        />

        <Sheet.Frame
          p="$4"
          py={"$6"}
          justify="flex-start"
          items="center"
          gap="$5"
          bg={"$accent12"}
          width={"100%"}
          mx={"auto"}
        >
          <SheetContents {...{ setPosition, position }} />
        </Sheet.Frame>
      </Sheet>
    </>
  );
};

export default OnBoarding;
