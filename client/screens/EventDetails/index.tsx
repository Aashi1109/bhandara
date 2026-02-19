import React, { useCallback, useEffect, useRef, useState } from "react";

import { getEventById, getEventThreads , updateEvent } from "@/common/api/events.action";
import { BackButtonHeader, IdentityCard, TagListing, UserCluster } from "@/components/ui/common-components";
import { CardWrapper, CircleBgWrapper, PopoverContent } from "@/components/ui/common-styles";
import { SpinningLoader } from "@/components/ui/Loaders";
import ProfileAvatarPreview from "@/components/ui/ProfileAvatarPreview";
import { EEventType, EMediaType , EEventStatus } from "@/definitions/enums";
import type { IBaseThread, IBaseUser, IEvent } from "@/definitions/types";
import { useDataLoader } from "@/hooks";
import { ChevronRight, Plus, Share2, MoreVertical, Edit3, X, Calendar, RotateCcw } from "@tamagui/lucide-icons";
import { useToastController } from "@tamagui/toast";
import { useLocalSearchParams, useRouter } from "expo-router";
import { H4, H6, ScrollView, Sheet, Text, View, XStack, YStack } from "tamagui";
import { formatDateRange, formatDateWithTimeString } from "@/utils/date.utils";
import { omit, shareLink } from "@/utils";
import { useAuth } from "@/contexts/AuthContext";
import { PopoverWrapper } from "@/components/PopoverWrapper";
import config from "@/config";

import { PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import MapPreviewCard from "@/components/MapPreviewCard";
import VerifyEvent from "@/components/VerifyEvent";
import MessageCard from "./MessageView/MessageCard";
import type { IMessageViewAddMessageProp, IMessageViewBaseProps } from "./MessageView";
import MessageViewSheetContent from "./MessageViewSheetContent";
import { FilledButton, OutlineButton } from "@/components/ui/Buttons";
import PopoverMenuList from "@/components/PopoverMenuList";
import type { GestureResponderEvent } from "react-native";
import ConfirmationDialog from "@/components/ConfirmationDialog";
import { useDialog } from "@/hooks/useModal";
import { Badge } from "@/components/ui/Badge";
import Carousel from "@/components/Carousel";
import { ZoomableImage } from "./ZoomableImage";
import Video from "react-native-video";
import { useSocket } from "@/contexts/Socket";
import { getEventStatusFromDate } from "@/utils/event.utils";

export const VerifiersListing = ({ verifiers }: { verifiers: IEvent["verifiers"] }) => {
  // sort the latest ones first
  const _verifiers = Object.values(verifiers).sort(
    (a, b) => new Date(b.verifiedAt).getTime() - new Date(a.verifiedAt).getTime()
  );

  return (
    <CardWrapper gap={"$3"}>
      <H6>Verifiers</H6>
      {_verifiers.map((_verifier, index) => {
        const { user, verifiedAt } = _verifier;
        return (
          <XStack
            gap={"$4"}
            justify={"space-between"}
            key={verifiedAt.toString() + index}
          >
            <ProfileAvatarPreview
              user={user as IBaseUser}
              extraMeta={
                <>
                  <Text fontSize={"$2"}>Verified at</Text>
                  <Text
                    fontSize={"$2"}
                    color={"$color11"}
                  >
                    {formatDateWithTimeString(verifiedAt)}
                  </Text>
                </>
              }
            >
              <IdentityCard
                imageUrl={(user as IBaseUser).profilePic?.url || ""}
                title={(user as IBaseUser).name}
                subtitle={(user as IBaseUser).username ? `@${(user as IBaseUser).username}` : ""}
              />
            </ProfileAvatarPreview>
            <Badge outline-success>
              <Text
                fontSize={"$2"}
                color={"$green11"}
              >
                Verified
              </Text>
            </Badge>
          </XStack>
        );
      })}
    </CardWrapper>
  );
};

const tabs = [
  {
    label: "Share",
    icon: <Share2 />
  }
];

const EventDetails: React.FC = () => {
  const searchParams = useLocalSearchParams();
  const id = searchParams["id"] as string;
  const [_tabs, setTabs] = useState(tabs);

  const toastController = useToastController();

  const { data: _event, loading, setData: setEvent } = useDataLoader({ promiseFunction: fetchEventData });
  const { open, close, RenderContent } = useDialog();

  const {
    data: _threads,
    loading: threadsLoading,
    setData: setThreads
  } = useDataLoader({
    promiseFunction: getThreadsData,
    enabled: !!_event
  });

  async function fetchEventData() {
    try {
      const response = await getEventById(id as string);
      const status = getEventStatusFromDate(response.data.timings);

      if (response.data.status === EEventStatus.Cancelled && status === EEventStatus.Ongoing) {
        setTabs((prev) => [...prev, { label: "Re-open", icon: <RotateCcw /> }]);
      }
      switch (status) {
        case EEventStatus.Upcoming:
        case EEventStatus.Ongoing:
          setTabs((prev) => [
            ...prev,
            {
              label: "Edit",
              icon: <Edit3 />
            },
            { label: "Cancel", icon: <X /> }
          ]);
          break;
      }

      return response.data;
    } catch (error: any) {}
  }

  async function getThreadsData() {
    try {
      const data = await getEventThreads(id as string, {});
      if (data.error) throw data.error;
      return data.data.items as IBaseThread[];
    } catch (error: any) {
      toastController.show(error?.message ?? "Something went wrong");
    }
  }

  const createdBy = _event?.creator;
  const isOrganized = _event?.type === EEventType.Organized;
  const tags = _event?.tags;
  const participants = _event?.participants;
  const { user } = useAuth();
  const router = useRouter();
  const isOwner = user?.id === _event?.createdBy;

  const [isSheetOpen, setIsSheetOpen] = useState(false);

  const messageViewRef = useRef<{
    addMessage: (data: IMessageViewAddMessageProp) => void;
    handleClick: (data: Record<string, any>) => void;
  }>(null);
  const socket = useSocket();

  useEffect(() => {
    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_CREATED, ({ data }) => {
      if (!data || data.eventId !== id || !data.type) return;
      delete data.event;
      setThreads((prev) => [data, ...(prev || [])]);
    });

    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_UPDATED, ({ data }) => {
      if (!data) return;
      setThreads((prev) => {
        if (!prev) return prev;
        return prev.map((f) => (f.id === data.thread.id ? { ...f, ...data.thread } : f));
      });
    });

    socket.on(PLATFORM_SOCKET_EVENTS.THREAD_DELETED, ({ data }) => {
      if (!data) return;
      setThreads((prev) => {
        if (!prev) return prev;
        return prev.filter((f) => f.id !== data.thread.id);
      });
    });

    socket.on(PLATFORM_SOCKET_EVENTS.USER_UPDATED, ({ data }) => {
      if (!data) return;
      setEvent((prev) => {
        if (!prev) return prev;
        const updated = { ...prev } as any;
        if (updated.creator?.id === data.id) {
          updated.creator = { ...updated.creator, ...data };
        }
        if (updated.participants) {
          updated.participants = updated.participants.map((p: { user: IBaseUser }) =>
            p.user?.id === data.id ? { ...p, user: { ...p.user, ...data } } : p
          );
        }
        return updated;
      });
    });
  }, []);

  const [sheetStack, setSheetStack] = useState<IMessageViewBaseProps[]>([]);

  const handleClick = useCallback(
    ({
      messageId,
      threadId,
      parentId,
      eventId
    }: {
      messageId?: string;
      threadId?: string;
      parentId?: string;
      eventId?: string;
    }) => {
      if (messageId || threadId || parentId || eventId) {
        setSheetStack((prev) => [...prev, { parentId, threadId, messageId, eventId }]);
        setIsSheetOpen(true);
      }
    },
    []
  );

  const handleSheetBack = useCallback(() => {
    setSheetStack((prev) => {
      if (prev.length > 1) return prev.slice(0, -1);
      else {
        setIsSheetOpen(false);
        return [];
      }
    });
  }, []);

  const handleCancelEvent = async () => {
    await updateEvent(id as string, { status: EEventStatus.Cancelled });
    router.back();
  };

  const handleMenuAction = async (action: string, e?: GestureResponderEvent) => {
    e?.stopPropagation();
    switch (action) {
      case "edit":
        router.push(`/new-event?id=${_event?.id}`);
        break;
      case "share":
        shareLink(`${config.server.baseURL}/event/${_event?.id}`);
        break;
      case "cancel":
        open();
        break;
    }
  };

  const formattedTiming = formatDateRange(_event?.timings?.start!, _event?.timings?.end);
  const isVerified = _event?.verifiers.some((v) => {
    const id = typeof v.user === "string" ? v.user : v.user.id;
    return id === user?.id;
  });

  const groups = [
    {
      label: "General",
      tabs: tabs
    }
  ];

  return (
    <>
      <YStack
        p={"$4"}
        gap={"$4"}
        height={"100%"}
        overflow="hidden"
        bg={"$background"}
      >
        <BackButtonHeader
          title={_event?.name ?? "Event Details"}
          navigateTo="/home"
        >
          {isOwner ? (
            <PopoverWrapper
              trigger={
                <MoreVertical
                  size={24}
                  self={"flex-end"}
                  cursor="pointer"
                />
              }
            >
              <PopoverMenuList
                groups={groups}
                handleActionClick={handleMenuAction}
              />
            </PopoverWrapper>
          ) : (
            <View
              bg={"$color4"}
              rounded={"$4"}
              items={"center"}
              justify={"center"}
              cursor={"pointer"}
              height={"100%"}
              onPress={() => _event && shareLink(`${config.server.baseURL}/event/${_event.id}`)}
            >
              <Share2
                size={24}
                color={"$accent1"}
              />
            </View>
          )}
        </BackButtonHeader>
        <ScrollView
          gap={"$4"}
          flex={1}
          showsVerticalScrollIndicator={false}
          width={"100%"}
          $gtMd={{ items: "center" }}
        >
          {loading ? (
            <SpinningLoader />
          ) : (
            _event && (
              <YStack
                gap={"$4"}
                flex={1}
                $gtMd={{ maxW: 600 }}
              >
                <View px={"$2"}>
                  {!!_event?.media?.length && (
                    <Carousel
                      medias={_event.media}
                      renderMedia={(media) => {
                        if (media?.type === EMediaType.Image) {
                          return (
                            <ZoomableImage
                              uri={media?.publicUrl || ""}
                              containerStyle={{ width: "100%", height: 300, rounded: "$2" }}
                              scale={1}
                            />
                          );
                        }
                        if (media?.type === EMediaType.Video) {
                          return (
                            <Video
                              source={{ uri: media?.publicUrl }}
                              style={{ height: 300 }}
                              controls
                              paused
                              audioOutput="speaker"
                            />
                          );
                        }
                        return null;
                      }}
                      styles={{ width: "100%", justify: "center" }}
                    />
                  )}
                </View>

                {createdBy && (
                  <ProfileAvatarPreview user={createdBy}>
                    <IdentityCard
                      imageUrl={createdBy?.profilePic?.url || ""}
                      title={`${isOrganized ? "Organized by" : "Hosted by"  } ${  createdBy?.name}`}
                      subtitle={createdBy?.username ? `@${createdBy.username}` : ""}
                      imageAlt={createdBy?.name}
                    />
                  </ProfileAvatarPreview>
                )}
                <MapPreviewCard {..._event.location} />
                <CardWrapper
                  flexDirection="row"
                  items={"center"}
                  size={"medium"}
                >
                  <CircleBgWrapper
                    size={"$3"}
                    bg={"$color10"}
                  >
                    <Calendar size={16} />
                  </CircleBgWrapper>
                  <YStack>
                    <Text fontSize={"$4"}>{formattedTiming.dateRange}</Text>
                    <Text fontSize={"$2"}>{formattedTiming.timeRange}</Text>
                  </YStack>
                </CardWrapper>
                <CardWrapper>
                  <H6>Tags</H6>
                  <TagListing tags={tags || []} />
                </CardWrapper>

                {!!participants?.length && (
                  <CardWrapper>
                    <XStack
                      items={"center"}
                      justify={"space-between"}
                      gap={"$4"}
                    >
                      <H6>Attendees</H6>
                      {_event?.capacity && (
                        <Badge outline-success={true}>
                          <Badge.Text fontSize={"$2"}>
                            {participants.length}/{_event.capacity}
                          </Badge.Text>
                        </Badge>
                      )}
                    </XStack>
                    <UserCluster
                      users={participants.map((p) => p.user as IBaseUser)}
                      maxLimit={6}
                    />
                  </CardWrapper>
                )}

                {!!_event?.verifiers?.length && <VerifiersListing verifiers={_event.verifiers} />}

                <CardWrapper>
                  <XStack
                    gap={"$4"}
                    justify={"space-between"}
                  >
                    <H6>Discussion</H6>
                    <Plus
                      onPress={() => handleClick({ eventId: id })}
                      cursor="pointer"
                      size={20}
                    />
                  </XStack>
                  {threadsLoading ? (
                    <SpinningLoader />
                  ) : _threads?.length ? (
                    _threads?.map((thread) => {
                      return (
                        <View
                          flex={1}
                          width={"100%"}
                          key={thread.id}
                        >
                          <ChevronRight
                            size={20}
                            color={"$color"}
                            cursor="pointer"
                            position="absolute"
                            t={0}
                            r={0}
                            z={10}
                            onPress={() => {
                              handleClick({ threadId: thread?.id });
                            }}
                          />
                          <MessageCard
                            thread={omit(thread, ["messages"])}
                            handleClick={handleClick}
                            message={thread.messages![0]}
                          />
                        </View>
                      );
                    })
                  ) : (
                    <YStack
                      items={"center"}
                      justify={"center"}
                      gap={"$2"}
                    >
                      <Text fontSize={"$3"}>No threads yet. Start by creating one</Text>
                      <OutlineButton
                        size={"medium"}
                        width={150}
                        onPress={() => handleClick({ eventId: id })}
                      >
                        <Text>Start a thread</Text>
                      </OutlineButton>
                    </YStack>
                  )}
                </CardWrapper>
              </YStack>
            )
          )}
        </ScrollView>

        {_event && (
          <XStack
            gap={"$4"}
            flex={1}
            maxH={32}
            height={32}
            shrink={0}
          >
            {!isVerified && (
              <VerifyEvent
                event={_event}
                onVerified={(v) => setEvent((prev) => (prev ? { ...prev, verifiers: [...prev.verifiers, v] } : prev))}
                buttonStyles={{
                  flex: 1,
                  width: "50%",
                  py: "$2"
                }}
              />
            )}
            {(_event?.status === EEventStatus.Upcoming || _event?.status === EEventStatus.Ongoing) && (
              <FilledButton
                flex={1}
                width={"50%"}
                py={"$1"}
              >
                <Text
                  fontSize={"$3"}
                  color={"$color1"}
                >
                  {_event.status === EEventStatus.Upcoming ? "Join" : "Register Now"}
                </Text>
              </FilledButton>
            )}
          </XStack>
        )}
      </YStack>

      <Sheet
        modal={true}
        defaultOpen={false}
        open={isSheetOpen}
        zIndex={20}
        animation={"quick"}
        dismissOnOverlayPress={false}
        dismissOnSnapToBottom={false}
        snapPoints={[80]}
        defaultPosition={0}
        snapPointsMode="percent"
      >
        <Sheet.Overlay
          shadowColor={"$black1"}
          opacity={0.7}
          z={10}
        />
        <Sheet.Handle bg={"$color4"} />
        <Sheet.Frame
          p="$4"
          justify="flex-start"
          items="center"
          gap="$2"
          bg={"$accent12"}
          mx={"auto"}
        >
          <MessageViewSheetContent
            messageViewRef={messageViewRef}
            setIsSheetOpen={setIsSheetOpen}
            sheetStack={sheetStack}
            handleClick={handleClick}
            handleSheetBack={handleSheetBack}
          />
        </Sheet.Frame>
      </Sheet>

      <RenderContent>
        <ConfirmationDialog
          title={_event?.status === EEventStatus.Cancelled ? "Re-open Event" : "Cancel Event"}
          description={
            _event?.status === EEventStatus.Cancelled
              ? "Are you sure you want to re-open this event?"
              : "Are you sure you want to cancel this event?"
          }
          onClose={close}
          onConfirm={handleCancelEvent}
          asDanger
        />
      </RenderContent>
    </>
  );
};

export default EventDetails;
