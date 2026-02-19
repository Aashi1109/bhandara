import { XStack , Dialog } from "tamagui";
import React, { useState } from "react";
import { FilledButton, OutlineButton } from "./ui/Buttons";
import { SpinningLoader } from "./ui/Loaders";
import { DialogContent, DialogTitle } from "./ui/common-styles";

const ConfirmationDialog = ({
  title,
  description,
  onClose,
  onConfirm,
  asDanger
}: {
  title: string;
  description: string;
  onClose: () => void;
  onConfirm: () => Promise<void>;
  asDanger?: boolean;
}) => {
  const [isLoading, setIsLoading] = useState(false);

  const handleConfirm = async () => {
    setIsLoading(true);
    try {
      await onConfirm();
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <>
      <DialogTitle>{title}</DialogTitle>
      <Dialog.Description>{description}</Dialog.Description>

      <XStack
        justify={"flex-end"}
        gap="$2"
      >
        <Dialog.Close asChild>
          <OutlineButton
            disabled={isLoading}
            onPress={onClose}
            width={"auto"}
            size={"medium"}
          >
            Cancel
          </OutlineButton>
        </Dialog.Close>
        <FilledButton
          danger={asDanger}
          disabled={isLoading}
          onPress={handleConfirm}
          width={"auto"}
          size={"medium"}
          iconAfter={isLoading ? <SpinningLoader /> : undefined}
        >
          Confirm
        </FilledButton>
      </XStack>
    </>
  );
};

export default ConfirmationDialog;
