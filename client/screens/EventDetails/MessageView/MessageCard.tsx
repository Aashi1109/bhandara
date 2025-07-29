import CustomAvatar from "@/components/CustomAvatar";
import { UserCluster } from "@/components/ui/common-components";
import { CardWrapper } from "@/components/ui/common-styles";
import { useAuth } from "@/contexts/AuthContext";
import { IBaseUser, IMedia, IMessage, IReaction, IBaseThread } from "@/definitions/types";
import { useEffect, useRef, useState } from "react";
import { AnimatePresence, ScrollView, TamaguiElement, Text, View, XStack, YStack } from "tamagui";
import React from "react";
import { formatDateWithTimeString } from "@/utils/date.utils";
import AssetPreview from "@/components/MessageInputBar/AssetPreview";
import { isEmpty } from "@/utils";
import { MoreVertical, Lock } from "@tamagui/lucide-icons";
import WithDoubleTap from "@/components/WithDoubleTap";
import { useSocket } from "@/contexts/Socket";
import { COMMON_EMOJIS, PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import { useToastController } from "@tamagui/toast";
import useSocketListener from "@/hooks/useSocketListener";
import { useDialog } from "@/hooks/useModal";
import AssetPreviewDialog from "../AssetPreviewDialog";
import { isThreadLocked } from "@/utils/thread.utils";

interface ThreadCardProps {
  thread: { id: string } & Partial<IBaseThread>;
  message: IMessage;
  handleClick: (data: Record<string, any>) => void;
  isFirst?: boolean;
}

function MessageCard({ thread, message, handleClick, isFirst = false }: ThreadCardProps) {
  const { user: currentUserProfile } = useAuth();
  const socket = useSocket();
  const toastController = useToastController();

  const userProfileUrl = message?.user?.profilePic?.url || "";
  const userName = currentUserProfile?.id === message?.user?.id ? "You" : message?.user?.name || "";
  const childMessages = message?.children?.items;
  const totalChildMessages = message?.children?.pagination?.total || 0;
  const [reactions, setReactions] = useState(() => message?.reactions || []);

  const childMessagesUser = (childMessages || []).map((ch) => ch.user).filter((i) => !!i);

  const maxRepliesUserToShow = 3;
  const userForCluster = childMessagesUser.slice(0, maxRepliesUserToShow);

  const lineRef = useRef<TamaguiElement>(null);

  const remainingUserReplies = totalChildMessages - userForCluster.length;
  const media = (message?.content?.media || []) as IMedia[];

  const currentUserReaction = reactions?.find((f) => f.userId === currentUserProfile?.id);
  const [showActions, setShowActions] = useState(false);
  const { open, close, RenderContent } = useDialog();
  const currentSelectedMediaRef = useRef<undefined | string>();

  // Check if thread is locked
  const threadLocked = thread && 'lockHistory' in thread ? isThreadLocked(thread as IBaseThread) : false;

  useEffect(() => {
    if (!socket) return;
    socket.on(
      PLATFORM_SOCKET_EVENTS.REACTION_DELETED,
      ({
        data,
        error
      }: {
        data: { id: string; contentPath: string; reaction: IReaction; parentId: string };
        error: any;
      }) => {
        if (error || !data.parentId || data.id !== message.id) return;

        setReactions((prev) => prev.filter((f) => f.id !== data.reaction.id));
      }
    );

    socket.on(
      PLATFORM_SOCKET_EVENTS.REACTION_CREATED,
      ({
        data,
        error
      }: {
        data: { id: string; contentPath: string; reaction: IReaction; parentId: string };
        error: any;
      }) => {
        if (error || !data.parentId || data.id !== message.id) return;

        setReactions((prev) => [data.reaction, ...prev]);
      }
    );

    socket.on(
      PLATFORM_SOCKET_EVENTS.REACTION_UPDATED,
      ({
        data,
        error
      }: {
        data: { id: string; contentPath: string; reaction: IReaction; parentId: string };
        error: any;
      }) => {
        if (error || !data.parentId || data.id !== message.id) return;

        setReactions((prev) => prev.map((f) => (f.id === data.reaction.id ? { ...data.reaction } : f)));
      }
    );
  }, [socket]);

  const handleReactionPress = (e: string) => {
    // Prevent reactions if thread is locked
    if (threadLocked) {
      toastController.show("Thread is locked", {
        message: "Cannot add reactions to a locked thread",
      });
      return;
    }

    // if it is current user reaction update with current one
    socket?.emit(
      currentUserReaction
        ? currentUserReaction.emoji === e
          ? PLATFORM_SOCKET_EVENTS.REACTION_DELETED
          : PLATFORM_SOCKET_EVENTS.REACTION_UPDATED
        : PLATFORM_SOCKET_EVENTS.REACTION_CREATED,
      { contentId: message?.id, contentPath: "messages", reaction: e, parentId: thread?.id },
      ({ error }) => {
        if (error) toastController.show(error);
        else {
          handleHoverOut();
        }
      }
    );
  };

  const handleHoverIn = () => {
    // Don't show reaction actions if thread is locked
    if (!threadLocked) {
      setShowActions(true);
    }
  };
  const handleHoverOut = () => {
    setShowActions(false);
  };

  const handleAssetClick = (e: IMedia) => {
    currentSelectedMediaRef.current = e.id;
    open();
  };

  return (
    <>
      <WithDoubleTap
        onDoubleTap={() => {
          console.log("doible clikc");
        }}
      >
        <XStack
          gap="$3"
          items="flex-start"
          py={"$2"}
          position="relative"
          hoverStyle={{ bg: "$color3" }}
          onHoverIn={handleHoverIn}
          onHoverOut={handleHoverOut}
          flex={1}
          width={"100%"}
          onLayout={(e) => {
            const { nativeEvent } = e;
            if (lineRef.current) {
              // @ts-ignore
              lineRef.current.style.height = `${nativeEvent.layout.height - (reactions?.length ? 102 : 64)}px`;
            }
          }}
        >
          <CustomAvatar
            src={userProfileUrl}
            alt={userName}
            size={32}
          />
          <YStack
            gap="$1"
            flex={1}
            position="unset"
          >
            <XStack
              gap="$2"
              items="center"
              justify={"flex-start"}
            >
              <Text fontSize={"$4"}>{userName}</Text>
              <Text
                color="$color10"
                fontWeight={"100"}
                fontSize="$1"
              >
                {formatDateWithTimeString(new Date(message?.createdAt))}
              </Text>
            </XStack>
            {message?.content?.text && (
              <Text
                fontSize={"$3"}
                color="$color11"
              >
                {message.content.text}
              </Text>
            )}
            {!!media?.length && (
              <ScrollView horizontal>
                <XStack
                  gap={"$2"}
                  mt={"$2"}
                >
                  {media.map((m) => {
                    if (isEmpty(m)) return null;
                    return (
                      <View
                        onPress={() => handleAssetClick(m)}
                        key={m?.id}
                      >
                        <AssetPreview
                          key={m?.id}
                          type={m?.type}
                          publicLink={m?.publicUrl}
                          size={100}
                        />
                      </View>
                    );
                  })}
                </XStack>
              </ScrollView>
            )}

            {!!childMessages?.length && (
              <>
                <CardWrapper
                  gap={"$3.5"}
                  mt={"$2"}
                  flexDirection="row"
                  width={"auto"}
                  p={0}
                  self={"flex-start"}
                  items={"center"}
                  rounded={0}
                  borderColor={"transparent"}
                  cursor="pointer"
                  onPress={() => handleClick({ parentId: message?.id, threadId: thread?.id })}
                >
                  <UserCluster
                    users={userForCluster as IBaseUser[]}
                    avatarSize={24}
                  />
                  <Text
                    fontWeight="600"
                    color="$blue10"
                  >
                    {childMessages?.length}
                  </Text>
                  <Text
                    fontSize={"$3"}
                    borderBottomWidth={"$0.5"}
                    borderColor={"transparent"}
                    hoverStyle={{ borderColor: "$color12" }}
                    transition="border .2s ease-in"
                  >
                    {remainingUserReplies > 0 ? `+${remainingUserReplies} Replies` : "View Thread"}
                  </Text>
                </CardWrapper>

                <View
                  position="absolute"
                  borderColor={"$color8"}
                  borderLeftWidth={"$0.75"}
                  borderBottomWidth={"$0.75"}
                  width={26}
                  b={!!reactions?.length ? 37 + 20 : 20}
                  l={15}
                  z={1}
                  borderBottomLeftRadius={"$4"}
                  ref={lineRef}
                />
              </>
            )}

            {!!reactions?.length && (
              <CardWrapper
                gap={"$3"}
                items={"center"}
                self={"flex-start"}
                flexDirection="row"
                px={"$2"}
                py={"$1"}
                rounded={"$4"}
                width={"auto"}
                exitStyle={{ y: 10, opacity: 0 }}
                enterStyle={{ y: -10, opacity: 1 }}
                animation={"quick"}
                onHoverIn={(e) => e.stopPropagation()}
                mt={"$0.5"}
              >
                {reactions.map((e) => (
                  <Text
                    onPress={() => handleReactionPress(e.emoji)}
                    cursor="pointer"
                    key={e?.id}
                  >
                    {e.emoji}
                  </Text>
                ))}
              </CardWrapper>
            )}
          </YStack>
          {/* actions */}

          <AnimatePresence>
            {showActions && (
              <CardWrapper
                gap={"$3"}
                items={"center"}
                flexDirection="row"
                position="absolute"
                p={"$2"}
                t={isFirst ? 0 : -18}
                rounded={"$4"}
                r={20}
                width={"auto"}
                exitStyle={{ y: 10, opacity: 0 }}
                enterStyle={{ y: -10, opacity: 1 }}
                animation={"quick"}
              >
                {COMMON_EMOJIS.map((e) => (
                  <Text
                    onPress={() => handleReactionPress(e)}
                    cursor="pointer"
                    hoverStyle={{ transform: "translateY(-5px)" }}
                    transition="transform 0.3s ease-in"
                    key={e}
                  >
                    {e}
                  </Text>
                ))}
                <MoreVertical
                  size={16}
                  cursor="pointer"
                />
              </CardWrapper>
            )}
          </AnimatePresence>
        </XStack>
      </WithDoubleTap>

      <RenderContent>
        <AssetPreviewDialog
          medias={media}
          currentSelectedMediaId={currentSelectedMediaRef.current}
          close={close}
        />
      </RenderContent>
    </>
  );
}

export default MessageCard;
