import React from "react";
import AvatarSelection from "./AvatarSelection";
import type { FieldErrors, UseFormSetError, UseFormSetValue , Control } from "react-hook-form";
import type { IFormData } from "./type";

import GenderSelection from "./GenderSelection";
import LocationInput from "@/components/LocationInput";
import UsernameInput from "@/components/UsernameInput";

interface IProps {
  allValues: IFormData;
  setValue: UseFormSetValue<IFormData>;
  control: Control<IFormData>;
  errors: FieldErrors<IFormData>;
  setError: UseFormSetError<IFormData>;
}

const ProfileSetup = ({ allValues, setValue, control, errors, setError }: IProps) => {
  return (
    <>
      <AvatarSelection
        preSelectedAvatar={allValues.profilePic?.url}
        cb={(avatar) => {
          setValue("profilePic.url", avatar);
        }}
      />
      <UsernameInput
        control={control}
        currentValue={allValues.username}
        error={errors.username?.message}
        setError={setError}
      />

      <GenderSelection
        preSelectedGender={allValues.gender}
        cb={(gender) => {
          setValue("gender", gender);
        }}
      />

      <LocationInput
        existingLocation={{
          ...(allValues.location || {}),
          _location: allValues._location || ""
        }}
        setValue={(value) => {
          const { _location, ...rest } = value;
          setValue("location", {
            ...rest
          });
          setValue("_location", _location);
        }}
        control={control}
        errors={{ ...errors._location, ...errors.location }}
      />
    </>
  );
};

export default ProfileSetup;
