import React, { useState } from "react";
import { CircleBgWrapper, PopoverContent } from "../../ui/common-styles";
import { Popover, Text, Theme } from "tamagui";
import { XStack } from "tamagui";
import { Plus } from "@tamagui/lucide-icons";
import * as DocumentPicker from "expo-document-picker";

import { useToastController } from "@tamagui/toast";
import { IAttachedFile, processPickedFiles } from "@/common/utils/file.utils";
import { EVENT_MEDIA_BUCKET } from "@/constants/global";

interface IProps {
  eventId: string;
  attachedFiles: IAttachedFile[];
  setAttachedFiles: React.Dispatch<React.SetStateAction<IAttachedFile[]>>;
  maxAttachmentLimit?: number;
}

const AddPopoverContents = ({ eventId, setAttachedFiles, attachedFiles, maxAttachmentLimit }: IProps) => {
  const toastController = useToastController();
  const [isUploading, setIsUploading] = useState(false);

  const handleFilePick = async () => {
    const file = await DocumentPicker.getDocumentAsync({
      type: ["image/*", "video/*"],
      multiple: true
    });

    if (file && !file.canceled) {
      try {
        setIsUploading(true);
        if (maxAttachmentLimit) {
          const currentAssetsCount = attachedFiles.filter((f) => !f.error).length;
          const availableSlots = maxAttachmentLimit - currentAssetsCount;
          
          if (availableSlots <= 0) {
            toastController.show(
              `You can only upload ${maxAttachmentLimit} ${maxAttachmentLimit === 1 ? "file" : "files"} at a time`
            );
            return;
          }
          
          // Limit the number of files that can be added
          file.assets = file.assets.slice(0, availableSlots);
          
          if (file.assets.length === 0) {
            toastController.show(
              `You can only upload ${maxAttachmentLimit} ${maxAttachmentLimit === 1 ? "file" : "files"} at a time`
            );
            return;
          }
        }

        file.assets = file.assets
          .filter((f) => f.size) // keep only files with size
          .filter((f, idx, arr) => arr.findIndex((_f) => _f.name === f.name) === idx); // remove duplicates by name
        const { successCount, errorCount } = await processPickedFiles({
          files: file.assets,
          opts: { pPath: eventId, bucket: EVENT_MEDIA_BUCKET },
          setAttachedFiles
        });

        if (successCount > 0) {
          toastController.show(`Uploaded ${successCount} ${successCount === 1 ? "file" : "files"} successfully`);
        }
        if (errorCount > 0) {
          toastController.show(
            `${errorCount} ${errorCount === 1 ? "file" : "files"} failed to upload. You can retry uploading them.`
          );
        }
      } catch (error: any) {
        toastController.show(error?.message || "Something went wrong");
      } finally {
        setIsUploading(false);
      }
    }
  };

  return (
    <PopoverContent
      mr="$4"
      z={10000}
      p={"$2"}
    >
      <Theme name={"dark"}>
        <Popover.Close asChild>
          <XStack
            gap={"$2"}
            items={"center"}
            cursor={"pointer"}
            onPress={handleFilePick}
            px={"$2"}
            py={"$1"}
            hoverStyle={{ bg: "$color3", rounded: "$2" }}
            opacity={isUploading ? 0.6 : 1} // Visual feedback when uploading
            disabled={isUploading}
          >
            <CircleBgWrapper
              bg={"$color4"}
              height={24}
              width={24}
            >
              <Plus
                size={16}
                color={"$color12"}
              />
            </CircleBgWrapper>
            <Text
              fontSize={"$3"}
              color={"$color12"}
            >
              Upload files
            </Text>
          </XStack>
        </Popover.Close>
      </Theme>
    </PopoverContent>
  );
};

export default AddPopoverContents;
