import { OutlineButton } from "@/components/ui/Buttons";
import React, { useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { Button, Input, Label, Paragraph, Text, XStack, YStack } from "tamagui";

type FormData = {
  firstName: string;
  lastName: string;
  email: string;
  password: string;
};

const AuthForm = ({ isSignUp = false, cb }: { isSignUp?: boolean; cb: (data: FormData) => void }) => {
  const {
    control,
    handleSubmit,
    formState: { errors }
  } = useForm<FormData>({
    defaultValues: {
      firstName: "",
      lastName: "",
      email: "",
      password: ""
    },
    mode: "all"
  });

  const onSubmit = (data: FormData) => {
    cb(data);
  };

  return (
    <YStack
      gap={"$5"}
      width={"100%"}
      justify={"space-between"}
      flex={1}
    >
      <YStack
        gap="$5"
        flex={1}
      >
        {isSignUp ? (
          <XStack
            gap="$4"
            transition={"quick"}
            enterStyle={{ opacity: 0, y: 15 }}
            exitStyle={{ opacity: 0, y: -15 }}
            key="signup-fields"
            width="100%"
            height={"auto"}
          >
            <YStack
              flex={1}
              gap="$2"
            >
              <XStack
                gap="$2"
                justify="space-between"
                items="center"
              >
                <Text minH={0}>First name</Text>
                <Paragraph
                  size="$1"
                  color="$color8"
                >
                  Optional
                </Paragraph>
              </XStack>
              <Controller
                control={control}
                name="firstName"
                rules={{
                  minLength: { value: 2, message: "First name must be at least 2 characters" },
                  pattern: { value: /^[A-Za-z]+$/, message: "Please enter valid characters" }
                }}
                render={({ field }) => (
                  <>
                    <Input
                      placeholder="First name"
                      value={field.value}
                      onChangeText={field.onChange}
                      borderColor={errors.firstName ? "$red8" : undefined}
                    />
                    {errors.firstName && (
                      <Text
                        color="$red10"
                        fontSize="$1"
                      >
                        {errors.firstName.message}
                      </Text>
                    )}
                  </>
                )}
              />
            </YStack>
            <YStack
              flex={1}
              gap="$2"
            >
              <XStack
                gap="$2"
                justify="space-between"
                items="center"
              >
                <Text>Last name</Text>
                <Paragraph
                  size="$1"
                  color="$color8"
                >
                  Optional
                </Paragraph>
              </XStack>
              <Controller
                control={control}
                name="lastName"
                rules={{
                  minLength: { value: 2, message: "Last name must be at least 2 characters" },
                  pattern: { value: /^[A-Za-z]+$/, message: "Please enter valid characters" }
                }}
                render={({ field }) => (
                  <>
                    <Input
                      placeholder="Last name"
                      value={field.value}
                      onChangeText={field.onChange}
                      borderColor={errors.lastName ? "$red8" : undefined}
                    />
                    {errors.lastName && (
                      <Text
                        color="$red10"
                        fontSize="$1"
                      >
                        {errors.lastName.message}
                      </Text>
                    )}
                  </>
                )}
              />
            </YStack>
          </XStack>
        ) : null}

        <YStack
          gap="$2"
          position="relative"
        >
          <Text fontSize={"$3"}>Email address</Text>
          <Controller
            control={control}
            name="email"
            rules={{
              required: "Email is required",
              pattern: {
                value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
                message: "Please enter a valid email address"
              }
            }}
            render={({ field }) => (
              <>
                <Input
                  placeholder="Enter your email address"
                  value={field.value}
                  onChangeText={field.onChange}
                  keyboardType="email-address"
                  borderColor={errors.email ? "$red8" : undefined}
                />
                {errors.email && (
                  <Text
                    color="$red10"
                    fontSize="$1"
                  >
                    {errors.email.message}
                  </Text>
                )}
              </>
            )}
          />
        </YStack>

        <YStack gap="$2">
          <Text fontSize={"$3"}>Password</Text>
          <Controller
            control={control}
            name="password"
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
            render={({ field }) => (
              <>
                <Input
                  placeholder="Enter your password"
                  secureTextEntry
                  value={field.value}
                  onChangeText={field.onChange}
                  borderColor={errors.password ? "$red8" : undefined}
                />
                {errors.password && (
                  <Text
                    color="$red10"
                    fontSize="$1"
                  >
                    {errors.password.message}
                  </Text>
                )}
              </>
            )}
          />
        </YStack>
      </YStack>

      {/* Submit Button */}
      <OutlineButton
        onPress={handleSubmit(onSubmit)}
        transition="quick"
        enterStyle={{ opacity: 0, scale: 0.9 }}
        exitStyle={{ opacity: 0, scale: 0.9 }}
      >
        Continue
      </OutlineButton>
    </YStack>
  );
};

export default AuthForm;
