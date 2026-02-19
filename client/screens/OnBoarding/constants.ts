import { EOnboardingStages } from "@/definitions/enums";
import { EApplicableStage } from "./enum";
import type { IFormData } from "./type";

export const GET_STARTED_TABS = [
  {
    title: "Explore Nearby Events",
    description: "Get notified about nearby food events and much more. Register for notifications and much more.",
    renderComponent: () => null
  },
  {
    title: "Event Exploration made Simple",
    description:
      "Discover, book, and track events seamlessly with calendar integration and personalized event curation",
    renderComponent: () => null
  }
];

export const ONBOARDING_STAGES_TEXT = {
  [EOnboardingStages.EmailVerification]: {
    title: "Continue with Email",
    description: "Sign in or Sign up with your email"
  },
  [EOnboardingStages.BasicInfo]: {
    title: "Let's get started",
    description: "Please fill out the details to continue"
  },
  [EOnboardingStages.ProfileSetup]: {
    title: "One more step",
    description: "Choose an avatar and username"
  },
  [EOnboardingStages.InterestSelection]: {
    title: "Tell us your interests",
    description: "Choose between 3 and 10 interests, and we'll curate the best events for your feed"
  },
  [EOnboardingStages.Login]: {
    title: "Welcome back",
    description: "Sign in to your account"
  }
};

export const APPLICABLE_STAGES_MAP = {
  [EApplicableStage.EmailExists]: {
    stages: [EOnboardingStages.EmailVerification, EOnboardingStages.Login],
    skippableStages: []
  },
  [EApplicableStage.NotOnboarded]: {
    stages: [EOnboardingStages.BasicInfo, EOnboardingStages.ProfileSetup, EOnboardingStages.InterestSelection],
    skippableStages: [EOnboardingStages.InterestSelection]
  },
  [EApplicableStage.NewUser]: {
    stages: [EOnboardingStages.BasicInfo, EOnboardingStages.ProfileSetup, EOnboardingStages.InterestSelection],
    skippableStages: [EOnboardingStages.InterestSelection]
  }
};

export const getStageLevelFields = (stage: EOnboardingStages, isUserComingFromSocialAuth: boolean) => {
  const stageFields = {
    [EOnboardingStages.EmailVerification]: ["email"],
    [EOnboardingStages.Login]: ["email", "password"],
    [EOnboardingStages.BasicInfo]: [
      "firstName",
      "lastName",
      "email",
      ...(isUserComingFromSocialAuth ? [] : ["password", "verifyPassword"])
    ],
    [EOnboardingStages.ProfileSetup]: ["username", "profilePic", "location"],
    [EOnboardingStages.InterestSelection]: ["interests"]
  };

  return stageFields[stage] as (keyof IFormData)[];
};
