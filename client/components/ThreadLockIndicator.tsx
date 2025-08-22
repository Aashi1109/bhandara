import React from "react";
import { XStack, YStack, Text, View } from "tamagui";
import { Lock, Unlock } from "@tamagui/lucide-icons";
import { Badge } from "./ui/Badge";
import { IBaseThread } from "@/definitions/types";
import { isThreadLocked, getThreadLockStatusMessage, canUserLockThread } from "@/utils/thread.utils";
import { useAuth } from "@/contexts/AuthContext";
import { OutlineButton } from "./ui/Buttons";
import { lockThread, unlockThread } from "@/common/api/threads.action";
import { useToastController } from "@tamagui/toast";

interface ThreadLockIndicatorProps {
  thread: IBaseThread;
  onLockStatusChange?: (isLocked: boolean) => void;
  showControls?: boolean;
}

const ThreadLockIndicator: React.FC<ThreadLockIndicatorProps> = ({ 
  thread, 
  onLockStatusChange,
  showControls = true 
}) => {
  const { user } = useAuth();
  const toastController = useToastController();
  const [isLoading, setIsLoading] = React.useState(false);

  const locked = isThreadLocked(thread);
  const canControl = user && canUserLockThread(thread, user.id);
  const lockMessage = getThreadLockStatusMessage(thread, user?.id);

  const handleLockToggle = async () => {
    if (!user || !canControl) return;

    setIsLoading(true);
    try {
      if (locked) {
        await unlockThread(thread.id);
        toastController.show("Thread unlocked successfully", {
          message: "Users can now add messages and reactions",
        });
      } else {
        await lockThread(thread.id);
        toastController.show("Thread locked successfully", {
          message: "No new messages or reactions can be added",
        });
      }
      onLockStatusChange?.(!locked);
    } catch (error: any) {
      toastController.show("Error", {
        message: error?.response?.data?.error || error?.message || "Something went wrong",
      });
    } finally {
      setIsLoading(false);
    }
  };

  if (!locked && !canControl) {
    return null; // Don't show anything if thread is not locked and user can't control it
  }

  return (
    <XStack gap="$3" alignItems="center" paddingVertical="$2">
      {/* Lock Status Badge */}
      <Badge variant={locked ? "danger" : "success"}>
        <XStack gap="$2" alignItems="center">
          {locked ? <Lock size={14} /> : <Unlock size={14} />}
          <Text fontSize="$2" fontWeight="600">
            {locked ? "Locked" : "Unlocked"}
          </Text>
        </XStack>
      </Badge>

      {/* Lock Message */}
      {lockMessage && (
        <Text fontSize="$2" color="$color10">
          {lockMessage}
        </Text>
      )}

      {/* Controls for thread author */}
      {showControls && canControl && (
        <OutlineButton
          size="$2"
          onPress={handleLockToggle}
          disabled={isLoading}
          variant={locked ? "success" : "danger"}
        >
          <XStack gap="$2" alignItems="center">
            {locked ? <Unlock size={14} /> : <Lock size={14} />}
            <Text fontSize="$2">
              {isLoading ? "Processing..." : locked ? "Unlock" : "Lock"}
            </Text>
          </XStack>
        </OutlineButton>
      )}
    </XStack>
  );
};

export default ThreadLockIndicator;