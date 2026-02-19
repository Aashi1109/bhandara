import { updateUser } from "@/common/api/user.action";
import { useAuth } from "@/contexts/AuthContext";
import type { ITag } from "@/definitions/types";
import InterestSelection from "@/screens/OnBoarding/InterestSelection";
import { isEmpty } from "@/utils";
import { useToastController } from "@tamagui/toast";
import React, { useRef, useState } from "react";
import { H5, View, XStack } from "tamagui";
import { FilledButton, OutlineButton } from "./ui/Buttons";
import { SpinningLoader } from "./ui/Loaders";
import { CardWrapper } from "./ui/common-styles";

const InterestsDialog = ({
  closeModal,
  preSelectedTags,
  onUpdateInterests,
  title
}: {
  closeModal: () => void;
  preSelectedTags: ITag[];
  onUpdateInterests: (payload: { deleted: ITag[]; added?: ITag[]; currentSelectedTags: ITag[] }) => Promise<void>;
  title: string;
}) => {
  const toastController = useToastController();
  const selectedInterestsRef = useRef<ITag[]>([]);
  const [isSaving, setIsSaving] = useState(false);

  const handleUpdateInterests = async () => {
    if (isEmpty(selectedInterestsRef.current)) {
      closeModal();
      return;
    }

    setIsSaving(true);

    try {
      // filter into deleted and added tags
      const deletedTags = preSelectedTags?.filter((tag: ITag) => !selectedInterestsRef.current.includes(tag));
      const addedTags = selectedInterestsRef.current?.filter((tag: ITag) => !preSelectedTags?.includes(tag));

      // update user with deleted and added tags
      const payload = {
        deleted: deletedTags,
        added: addedTags
      };
      await onUpdateInterests({ ...payload, currentSelectedTags: selectedInterestsRef.current });
      closeModal();
    } catch (error: any) {
      toastController.show(error?.message || "Something went wrong");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <View maxW={500}>
      <H5>{title}</H5>
      <InterestSelection
        cb={(tags) => {
          selectedInterestsRef.current = tags;
        }}
        maxH={400}
        preSelectedInterests={preSelectedTags || []}
      />
      <XStack
        justify={"flex-end"}
        gap={"$2"}
      >
        <OutlineButton
          width={"auto"}
          disabled={isSaving}
          size={"medium"}
          onPress={() => {
            closeModal();
            selectedInterestsRef.current = [];
          }}
        >
          Cancel
        </OutlineButton>
        <FilledButton
          size={"medium"}
          width={"auto"}
          onPress={handleUpdateInterests}
          disabled={isSaving}
          iconAfter={isSaving ? <SpinningLoader /> : undefined}
        >
          Update
        </FilledButton>
      </XStack>
    </View>
  );
};

export default InterestsDialog;
