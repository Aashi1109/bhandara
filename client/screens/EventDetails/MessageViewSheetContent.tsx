import React, { Dispatch, memo, Ref, RefObject, SetStateAction, useEffect, useState } from "react";
import MessageView, { IMessageViewAddMessageProp, IMessageViewBaseProps } from "./MessageView";
import { View } from "tamagui";
import MessageInputBar from "@/components/MessageInputBar";
import { useAuth } from "@/contexts/AuthContext";
import { PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import { useToastController } from "@tamagui/toast";
import { useLocalSearchParams } from "expo-router";
import { useSocket } from "@/contexts/Socket";
import { getThreadById } from "@/common/api/threads.action";
import { IBaseThread } from "@/definitions/types";
import ThreadLockIndicator from "@/components/ThreadLockIndicator";

interface Props {
  setIsSheetOpen: Dispatch<SetStateAction<boolean>>;
  messageViewRef: RefObject<any>;
  handleSheetBack: () => void;
  handleClick: (data: Record<string, any>) => void;
  sheetStack: Array<IMessageViewBaseProps>;
}

const MessageViewSheetContent = ({ handleClick, handleSheetBack, sheetStack }: Props) => {
  const { id } = useLocalSearchParams();

  const { user: currentAuthenticatedUser } = useAuth();
  const toastController = useToastController();
  const socket = useSocket();
  const [threadData, setThreadData] = useState<IBaseThread | null>(null);

  // Get the current thread ID from the top sheet
  const currentThreadId = sheetStack[sheetStack.length - 1]?.threadId;

  // Fetch thread data when threadId changes
  useEffect(() => {
    if (currentThreadId) {
      getThreadById({ id: currentThreadId })
        .then((response) => {
          setThreadData(response.data);
        })
        .catch((error) => {
          console.error("Error fetching thread:", error);
        });
    } else {
      setThreadData(null);
    }
  }, [currentThreadId]);

  // Handle thread lock/unlock events
  useEffect(() => {
    if (!socket || !currentThreadId) return;

    const handleThreadLocked = ({ data }: { data: { id: string; lockHistory: any[] } }) => {
      if (data.id === currentThreadId) {
        setThreadData((prev) => prev ? { ...prev, lockHistory: data.lockHistory } : null);
      }
    };

    const handleThreadUnlocked = ({ data }: { data: { id: string; lockHistory: any[] } }) => {
      if (data.id === currentThreadId) {
        setThreadData((prev) => prev ? { ...prev, lockHistory: data.lockHistory } : null);
      }
    };

    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_LOCKED, handleThreadLocked);
    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_UNLOCKED, handleThreadUnlocked);

    return () => {
      socket.off(PLATFORM_SOCKET_EVENTS.THREAD_LOCKED, handleThreadLocked);
      socket.off(PLATFORM_SOCKET_EVENTS.THREAD_UNLOCKED, handleThreadUnlocked);
    };
  }, [socket, currentThreadId]);

  return (
    <>
      <View
        position="relative"
        width={"100%"}
        flex={1}
      >
        {sheetStack.map((sheetData, index) => (
          <MessageView
            key={`${sheetData.threadId}-${sheetData.parentId}-${sheetData.messageId}-${index}`}
            {...sheetData}
            onBack={handleSheetBack}
            handleClick={handleClick}
            style={{
              position: "absolute",
              inset: 0,
              zIndex: index,
              display: index === sheetStack.length - 1 ? "flex" : "none"
            }}
          />
        ))}
      </View>

      {/* Show thread lock indicator if thread exists */}
      {threadData && (
        <ThreadLockIndicator 
          thread={threadData} 
          onLockStatusChange={(isLocked) => {
            // Update local thread data when lock status changes
            setThreadData((prev) => 
              prev ? { 
                ...prev, 
                lockHistory: isLocked ? [...(prev.lockHistory || []), { 
                  lockedBy: currentAuthenticatedUser?.id || '', 
                  lockedAt: new Date() 
                }] : []
              } : null
            );
          }}
        />
      )}

      <MessageInputBar
        context={{ eventId: id, maxAttachments: 3 }}
        thread={threadData}
        sendButtonCb={(data, onSuccess) => {
          // take the top most sheet data and based on that add message
          const topMostSheetData = sheetStack[sheetStack.length - 1];
          const { parentId, threadId, eventId } = topMostSheetData;

          const createNewThread = !threadId && eventId;
          const messageContent = {
            content: { text: data?.message, media: data?.mediaIds || [] }
          };
          const newMessage = {
            ...messageContent,
            userId: currentAuthenticatedUser?.id,
            parentId,
            threadId,
            isEdited: false,
            eventId
          };

          socket.emit(
            createNewThread ? PLATFORM_SOCKET_EVENTS.THREAD_CREATED : PLATFORM_SOCKET_EVENTS.MESSAGE_CREATED,
            newMessage,
            ({ error }: { data: IMessageViewAddMessageProp; error: any }) => {
              if (error) {
                toastController.show(error ?? "Something went wrong");
              } else {
                onSuccess?.();
              }
            }
          );
        }}
      />
    </>
  );
};

export default memo(MessageViewSheetContent);
