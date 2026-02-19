import { getUserInterests, updateUser } from "@/common/api/user.action";
import { InputGroup } from "@/components/Form";
import InterestsDialog from "@/components/InterestsDialog";
import LocationInput from "@/components/LocationInput";
import { OutlineButton } from "@/components/ui/Buttons";
import { TagListing } from "@/components/ui/common-components";
import { CardWrapper } from "@/components/ui/common-styles";
import { SpinningLoader } from "@/components/ui/Loaders";
import UsernameInput from "@/components/UsernameInput";
import { useAuth } from "@/contexts/AuthContext";
import type { IAddress, ITag } from "@/definitions/types";
import { useDataLoader } from "@/hooks";
import { useDialog } from "@/hooks/useModal";
import GenderSelection from "@/screens/OnBoarding/GenderSelection";
import { isEmpty, pick, startCase } from "@/utils";
import { Check, Pencil, Plus, X } from "@tamagui/lucide-icons";
import { useToastController } from "@tamagui/toast";
import React, { useState } from "react";
import { useForm } from "react-hook-form";
import { H5, Text, XStack, YStack } from "tamagui";

type IFormData = {
  fullName: string;
  email: string;
  gender: string;
  address?: IAddress;
  username?: string;
  _location?: string;
};

const Interests = ({ getInterestsPromise }: { getInterestsPromise: () => Promise<{ data?: ITag[]; error?: any }> }) => {
  const { user } = useAuth();
  const toastController = useToastController();
  const { close, open, RenderContent } = useDialog();

  const { data, loading, setData } = useDataLoader({ promiseFunction: asyncGetInterests });

  async function asyncGetInterests() {
    try {
      const { data, error } = await getInterestsPromise();
      if (error) throw error;
      return data;
    } catch (error: any) {
      toastController.show(error?.message || "Something went wrong");
    }
  }

  return (
    <>
      <CardWrapper>
        <XStack
          justify={"space-between"}
          items={"center"}
          gap={"$4"}
        >
          <H5>Interests</H5>
          {data?.length && (
            <Plus
              size={"$1"}
              cursor="pointer"
              onPress={open}
            />
          )}
        </XStack>
        {loading ? <SpinningLoader /> : <TagListing tags={data || []} />}
      </CardWrapper>

      <RenderContent>
        <InterestsDialog
          title="Add Interest"
          closeModal={close}
          preSelectedTags={data || []}
          onUpdateInterests={async ({ deleted, added, currentSelectedTags }) => {
            await updateUser(user!.id, {
              interests: { deleted: deleted?.map((i) => i.id), added: added?.map((i) => i.id) }
            });
            setData(currentSelectedTags);
          }}
        />
      </RenderContent>
    </>
  );
};

const InfoTabContent = () => {
  const { user, updateUser: updateContextUser } = useAuth();

  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const toastController = useToastController();

  const {
    control,
    setValue,
    setError,
    formState: { errors, isDirty },
    handleSubmit,
    reset
  } = useForm<IFormData>({
    defaultValues: {
      username: user?.username,
      address: user?.address || {},
      gender: user?.gender,
      _location: user?.address?.address || "",
      fullName: user?.name
    }
  });

  const viewInputs = pick(user, ["name", "email", "gender", "address.address", "username"]);

  const handleSave = async (data: IFormData) => {
    setIsSaving(true);
    try {
      const { fullName, gender, address, username, _location } = data;
      const payload = {
        name: fullName,
        gender,
        address: { ...(address || {}), address: _location },
        username
      };
      const res = await updateUser(user?.id || "", payload);
      if (!res.error) {
        setIsEditing(false);
        reset({ ...payload, _location: payload.address?.address }, { keepDirty: false });
        updateContextUser(payload);
        toastController.show("Profile updated successfully");
      } else {
        throw new Error(res.error);
      }
    } catch (error: any) {
      toastController.show(error?.error || "Something went wrong");
    } finally {
      setIsSaving(false);
    }
  };

  const handlePress = () => {
    if (isEditing) {
      handleSubmit(handleSave)();
    } else {
      setIsEditing((prev) => !prev);
    }
  };

  const isButtonDisabled = (!isDirty && isEditing && !Object.keys(errors).length) || isSaving;

  return (
    <YStack gap={"$4"}>
      <CardWrapper>
        <XStack
          gap={"$3"}
          items={"center"}
          justify={"space-between"}
        >
          <H5>Basic Info</H5>

          <XStack
            gap={"$3"}
            items={"center"}
            justify={"space-between"}
          >
            <OutlineButton
              size={"small"}
              icon={isEditing ? <Check /> : <Pencil />}
              onPress={handlePress}
              disabled={isButtonDisabled}
            >
              {isEditing ? "Save" : "Edit"}
            </OutlineButton>

            {isEditing && (
              <OutlineButton
                size={"small"}
                icon={<X />}
                onPress={() => setIsEditing(false)}
                danger={true}
              >
                Cancel
              </OutlineButton>
            )}
          </XStack>
        </XStack>

        <YStack gap={"$3"}>
          {isEditing ? (
            <>
              <InputGroup
                control={control}
                rules={{}}
                error={errors.fullName?.message}
                placeHolder="Name"
                name="fullName"
                label="Full Name"
              />
              {user?.gender && (
                <GenderSelection
                  disabled={!isEditing}
                  cb={(value) => {
                    setValue("gender", value, { shouldDirty: true });
                  }}
                  preSelectedGender={user?.gender}
                />
              )}
              {!isEmpty(user?.address) && (
                <LocationInput
                  existingLocation={{
                    ...(user?.address || {}),
                    _location: user?.address?.address || ""
                  }}
                  setValue={(value) => {
                    const { _location, ...rest } = value;
                    setValue(
                      "address",
                      {
                        ...rest
                      },
                      { shouldDirty: true }
                    );
                    setValue("_location", _location || "", { shouldDirty: true });
                  }}
                  control={control}
                  errors={{}}
                  isViewOnly={!isEditing}
                />
              )}

              {user?.username && (
                <UsernameInput
                  control={control}
                  currentValue={user?.username}
                  error={errors.username?.message}
                  setError={setError}
                  isViewOnly={!isEditing}
                />
              )}
            </>
          ) : (
            <>
              {Object.entries(viewInputs).map(([key, value]) => {
                const label = startCase(key);

                return (
                  <YStack
                    key={key}
                    gap={"$2"}
                  >
                    <Text fontSize={"$2"}>{label}</Text>
                    <Text
                      color={"$color11"}
                      fontSize={"$4"}
                    >
                      {value}
                    </Text>
                  </YStack>
                );
              })}
            </>
          )}
        </YStack>
      </CardWrapper>

      <Interests getInterestsPromise={() => getUserInterests(user?.id || "")} />
    </YStack>
  );
};

export default InfoTabContent;
