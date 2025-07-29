import React, { useState, useRef, useEffect } from "react";
import { CardWrapper } from "../ui/common-styles";
import { XStack, ScrollView, View, YStack, Text } from "tamagui";
import { Plus, RotateCw, SendHorizontal, X, Lock } from "@tamagui/lucide-icons";
import { FilledButton, OutlineButton } from "../ui/Buttons";
import { TextareaField } from "../Form";
import { Platform } from "react-native";
import { PopoverWrapper } from "../PopoverWrapper";
import AddPopoverContents from "./AddPopoverContents";
import { deleteMedia } from "@/common/api/media.action";
import AssetPreview from "./AssetPreview";
import { CircularProgressLoader, SpinningLoader } from "../ui/Loaders";
import CustomTooltip from "../CustomTooltip";
import { EMediaType } from "@/definitions/enums";
import { IAttachedFile } from "@/common/utils/file.utils";
import { Badge } from "../ui/Badge";
import { IBaseThread } from "@/definitions/types";
import { isThreadLocked } from "@/utils/thread.utils";

interface IProps {
  context: Record<string, any>;
  sendButtonCb: (data: Record<string, any>, onSuccess?: () => void) => void;
  thread?: IBaseThread; // Add thread prop to check lock status
}

const MessageInputBar = ({ context, sendButtonCb, thread }: IProps) => {
  const [message, setMessage] = useState("");
  const [attachedFiles, setAttachedFiles] = useState<IAttachedFile[]>([]);
  const textAreaRef = useRef<any>(null);

  const maxAttachmentLimit = context?.maxAttachments;
  const [height, setHeight] = useState(40);

  // Check if thread is locked
  const threadLocked = thread ? isThreadLocked(thread) : false;

  const handleMessageChange = (text: string) => {
    setMessage(text);
  };

  // Web paste handler
  const handleWebPaste = (e: React.ClipboardEvent<HTMLTextAreaElement>) => {
    const items = e.clipboardData?.items;
    if (!items) return;

    const fileItems: IAttachedFile[] = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i];

      // Check if the pasted item is a file
      if (item.kind === "file") {
        const file = item.getAsFile();
        if (file) {
          fileItems.push({
            name: file.name,
            type: file.type as EMediaType,
            size: file.size,
            uri: URL.createObjectURL(file),
            mimeType: file.type
          });
        }
      }
    }

    if (fileItems.length > 0) {
      // Check attachment limit before adding files
      if (maxAttachmentLimit) {
        const currentAssetsCount = attachedFiles.filter((f) => !f.error).length;
        const availableSlots = maxAttachmentLimit - currentAssetsCount;
        
        if (availableSlots <= 0) {
          // Prevent adding more files if limit is reached
          e.preventDefault();
          return;
        }
        
        // Limit the number of files that can be pasted
        fileItems.splice(availableSlots);
      }
      
      setAttachedFiles((prev) => [...prev, ...fileItems]);
      // Optional: prevent the default paste behavior for files
      // e.preventDefault();
    }
  };

  // Native clipboard check for files
  const checkNativeClipboard = async () => {
    try {
      // Check if clipboard has an image
      // const hasImage = await Clipboard.hasImageAsync();
      // if (hasImage) {
      //   const imageData = await Clipboard.getImageAsync({ format: "jpeg" });
      //   if (imageData?.data) {
      //     // Get filename from URI
      //     const uriParts = imageData.uri.split("/");
      //     const name = uriParts[uriParts.length - 1] || "clipboard-image.jpg";

      //     setAttachedFiles((prev) => [
      //       ...prev,
      //       {
      //         name,
      //         type: "image/jpeg", // Assume jpeg for simplicity
      //         size: 0, // Size not available
      //         data: imageData.base64 || "",
      //         uri: imageData.uri
      //       }
      //     ]);

      //     return true;
      //   }
      // }
      return false;
    } catch (error) {
      console.error("Error checking clipboard for images", error);
      return false;
    }
  };

  // Setup paste event listener for web
  useEffect(() => {
    if (Platform.OS === "web") {
      const currentRef = textAreaRef.current;
      if (currentRef) {
        // For web platform
        const handlePaste = (e: ClipboardEvent) => {
          // The implementation will be handled by onPaste prop
        };

        currentRef.addEventListener("paste", handlePaste);
        return () => {
          currentRef.removeEventListener("paste", handlePaste);
        };
      }
    }
  }, []);

  useEffect(() => {
    return () => {
      // delete all the attached files when user has exited but not sent the message
      if (attachedFiles.length) {
        const cleanup = async () => {
          try {
            await Promise.all(
              attachedFiles.map((f) => {
                if (f?.uploadResult?.id) {
                  return deleteMedia(f.uploadResult.id);
                } else {
                  return Promise.resolve(true);
                }
              })
            );
          } catch (error) {
            console.error("Error cleaning up attached files:", error);
          }
        };
        cleanup();
      }
    };
  }, [attachedFiles]);

  const removeAttachedFile = async (index: number) => {
    try {
      const uploadResult = attachedFiles[index].uploadResult;
      if (uploadResult) {
        setAttachedFiles((prev) => 
          prev.map((file, i) => 
            i === index ? { ...file, isDeleting: true } : file
          )
        );
        await deleteMedia(uploadResult?.id);
      }
      setAttachedFiles((prev) => prev.filter((_, i) => i !== index));
    } catch (error) {
      console.error("Error deleting file", error);
      setAttachedFiles((prev) => 
        prev.map((file, i) => 
          i === index ? { ...file, isDeleting: false } : file
        )
      );
    }
  };

  const handleSendMessageClick = () => {
    // create format to send to the parent callback
    const format = {
      message,
      attachments: attachedFiles.map((file) => {
        return {
          type: file.type,
          uri: file.uri,
          name: file.name,
          size: file.size,
          publicURL: file.publicURL
        };
      }),
      mediaIds: attachedFiles.map((file) => file?.uploadResult?.id).filter(Boolean)
    };
    sendButtonCb(format, () => {
      setMessage("");
      setAttachedFiles([]);
    });
  };

  const validFiles = attachedFiles.filter((file) => !file.error);
  const hasValidFiles = validFiles.length > 0;
  const validFilesCount = validFiles.length;
  const isAddButtonDisabled = !!maxAttachmentLimit ? maxAttachmentLimit <= validFilesCount : false;

  // If thread is locked, show a disabled state
  if (threadLocked) {
    return (
      <CardWrapper
        p={"$3"}
        rounded={"$3"}
        opacity={0.6}
        backgroundColor="$color2"
      >
        <XStack gap="$3" alignItems="center" justifyContent="center">
          <Lock size={16} color="$color8" />
          <Text fontSize="$3" color="$color8" textAlign="center">
            This thread is locked. No new messages can be added.
          </Text>
        </XStack>
      </CardWrapper>
    );
  }

  return (
    <CardWrapper
      p={"$3"}
      rounded={"$3"}
    >
      {attachedFiles.length > 0 && (
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
        >
          <XStack gap={"$2"}>
            {attachedFiles.map((file, index) => {
              const isUploading = file.uploadedRatio && file.uploadedRatio !== 100;
              const hasError = file.error;
              const showPreview = !isUploading && !hasError && (file.uri || file.publicURL);

              return (
                <YStack 
                  key={`${file.name}-${index}`}
                  gap={"$2"}
                >
                  <XStack
                    position="relative"
                    group
                    cursor="pointer"
                    height={50}
                    width={50}
                  >
                    {(isUploading || hasError) && (
                      <View
                        t={0}
                        l={0}
                        position="absolute"
                        height={50}
                        width={50}
                        items={"center"}
                        justify={"center"}
                        rounded={"$3"}
                        bg={file.error ? "$red1" : "rgba(0, 0, 0, 0.3)"}
                        borderColor={file.error ? "$red10" : "transparent"}
                        borderWidth={file.error ? "$0.25" : 0}
                        overflow="hidden"
                      >
                        {file.error ? (
                          <RotateCw
                            size={20}
                            cursor="pointer"
                            onPress={file.retryCallback}
                          />
                        ) : (
                          <CircularProgressLoader
                            size={24}
                            progress={file.uploadedRatio || 0}
                          />
                        )}
                      </View>
                    )}
                    {showPreview && (
                      <AssetPreview
                        type={file.type}
                        file={file.uri}
                        publicLink={file.publicURL}
                      />
                    )}

                    <OutlineButton
                      icon={file.isDeleting ? <SpinningLoader /> : <X size={12} />}
                      height={18}
                      p={"$1"}
                      width={18}
                      t={2}
                      r={2}
                      position="absolute"
                      disabled={file.isDeleting}
                      display={file.isDeleting ? "flex" : "none"}
                      onPress={() => removeAttachedFile(index)}
                      $group-hover={{
                        display: "flex"
                      }}
                    />

                    {/* {hasError && (
                      <Badge
                        outline-danger
                        rounded={1000}
                        group
                        width={20}
                      >
                        <XStack
                          gap={"$1.5"}
                          items={"center"}
                        >
                          <HelpCircle
                            color={"$red9"}
                            size={14}
                          />
                          <Text
                            fontSize={"$2"}
                            color={"$red9"}
                            display="none"
                            $group-hover={{ display: "flex" }}
                          >
                            {file.error}
                          </Text>
                        </XStack>
                      </Badge>
                    )} */}
                  </XStack>
                </YStack>
              );
            })}
          </XStack>
        </ScrollView>
      )}

      <TextareaField
        onChangeText={handleMessageChange}
        value={message}
        onKeyPress={(e) => {
          const { key } = e.nativeEvent;
          if (key === "Enter") {
            // For web, we can check if shift is pressed
            if (Platform.OS === "web") {
              const webEvent = e as any;
              if (webEvent.shiftKey) {
                return; // Allow new line
              }
            }
            handleSendMessageClick();
          }
        }}
        ref={textAreaRef}
        // For native platforms, check clipboard when focus is gained
        onFocus={Platform.OS !== "web" ? () => checkNativeClipboard() : undefined}
        numberOfLines={3}
        multiline
        onContentSizeChange={(e) => {
          const newHeight = e.nativeEvent.contentSize.height;
          setHeight(newHeight < 120 ? newHeight : 120); // optional max height cap
        }}
        height={height}
        p={0}
      />
      <XStack
        gap={"$4"}
        justify={"space-between"}
        items={"center"}
      >
        <PopoverWrapper
          trigger={
            isAddButtonDisabled ? (
              <CustomTooltip
                trigger={
                  <FilledButton
                    icon={<Plus size={16} />}
                    size={"$2"}
                    height={30}
                    width={30}
                    onPress={() => {}}
                    disabled={isAddButtonDisabled}
                  />
                }
              >
                <Badge>
                  <Badge.Text fontSize={"$2"}>
                    Max {maxAttachmentLimit} {maxAttachmentLimit === 1 ? "file" : "files"} supported
                  </Badge.Text>
                </Badge>
              </CustomTooltip>
            ) : (
              <FilledButton
                icon={<Plus size={16} />}
                size={"$2"}
                height={30}
                width={30}
                onPress={() => {}}
                disabled={isAddButtonDisabled}
              />
            )
          }
        >
          <AddPopoverContents
            eventId={context?.eventId || ""}
            setAttachedFiles={setAttachedFiles}
            attachedFiles={attachedFiles}
            maxAttachmentLimit={maxAttachmentLimit}
          />
        </PopoverWrapper>
        <FilledButton
          icon={<SendHorizontal size={16} />}
          size={"$2"}
          height={30}
          width={30}
          disabled={!message.trim() && !hasValidFiles}
          onPress={handleSendMessageClick}
        />
      </XStack>
    </CardWrapper>
  );
};

export default MessageInputBar;
