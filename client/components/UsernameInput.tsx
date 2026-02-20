import React, { useCallback, useState } from "react";
import { InputGroup } from "./Form";
import { debounce, View } from "tamagui";
import { type Control, type UseFormSetError, FieldErrors } from "react-hook-form";
import { getUserByUsername } from "@/common/api/user.action";
import { SpinningLoader } from "./ui/Loaders";
import { CircleCheck } from "@tamagui/lucide-icons";

interface IProps {
  control: Control<any>;
  error: string | undefined;
  setError: UseFormSetError<{ username: string }>;
  currentValue: string | undefined;
  isViewOnly?: boolean;
}

const UsernameInput = ({ control, currentValue, error, setError, isViewOnly }: IProps) => {
  const [usernameLoading, setUsernameLoading] = useState<boolean>(false);
  const [isUsernameAvailable, setIsUsernameAvailable] = useState<boolean>(false);

  const _getUserByUsername = async (username: string, error: string | undefined) => {
    try {
      if (!username || error) return;
      setUsernameLoading(true);
      await getUserByUsername(username);
      setError("username", { type: "custom", message: "Username is already taken" });
    } catch (error) {
      setUsernameLoading(false);
      setIsUsernameAvailable(true);
    }
  };

  const debouncedGetUserByUsername = useCallback(debounce(_getUserByUsername, 300), []);

  return (
    <InputGroup
      control={control}
      name="username"
      rules={{
        required: "Username is required",
        pattern: {
          value: /^[a-zA-Z][a-zA-Z0-9._]{4,19}$/,
          message:
            "Username must start with a letter, be 5-20 characters long, and can contain letters, numbers, dots, and underscores"
        }
      }}
      onChange={(value) => debouncedGetUserByUsername(value, error)}
      iconAfter={
        (usernameLoading || isUsernameAvailable) &&
        currentValue &&
        !error && (
          <View
            items="flex-end"
            justify="center"
            transition={"quick"}
            enterStyle={{ opacity: 0, scale: 0.5 }}
            exitStyle={{ opacity: 0, scale: 0.5 }}
          >
            {usernameLoading && <SpinningLoader />}

            {!usernameLoading && isUsernameAvailable && (
              <CircleCheck
                size={20}
                color="$green10"
              />
            )}
          </View>
        )
      }
      placeHolder="Enter your username"
      label="Username"
      rightLabel={isViewOnly ? "" : "Required"}
      error={error}
      inputProps={{
        editable: !isViewOnly
      }}
    />
  );
};

export default UsernameInput;
