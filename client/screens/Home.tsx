import { getAllEvents } from "@/common/api/events.action";
import CustomTooltip from "@/components/CustomTooltip";
import { FilledButton } from "@/components/ui/Buttons";
import { CircularFillIndicator, IdentityCard, TagPreviewTooltip, UserCluster } from "@/components/ui/common-components";
import { SpinningLoader } from "@/components/ui/Loaders";
import ProfileAvatarPreview from "@/components/ui/ProfileAvatarPreview";
import images from "@/constants/images";
import { EMediaType } from "@/definitions/enums";
import { IBaseUser, IEvent, ISearchFilters } from "@/definitions/types";
import { useDataLoader } from "@/hooks";
import useSocketListener from "@/hooks/useSocketListener";
import { PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import { Calendar, Check, Clock, MapPin } from "@tamagui/lucide-icons";
import { useToastController } from "@tamagui/toast";
import { useRouter } from "expo-router";
import React, { useEffect, useState } from "react";
import { H5, Image, ScrollView, Text, XStack, YStack } from "tamagui";

import { View } from "tamagui";
import VerifyEvent from "@/components/VerifyEvent";
import { Badge } from "@/components/ui/Badge";
import { useSocket } from "@/contexts/Socket";
import { FullSizeLoader } from "@/components/ui/common-styles";

const EventCard = ({ event }: { event: IEvent }) => {
  const [localEvent, setLocalEvent] = React.useState<IEvent>(event);
  const createdBy = localEvent.creator as IBaseUser;
  const router = useRouter();

  const previewEventImage = localEvent.media.find((media) => media.type === EMediaType.Image)?.publicUrl;

  const handleImagePress = () => {
    router.push(`/event/${localEvent.id}`);
  };

  return (
    <YStack
      rounded={"$4"}
      gap={"$4"}
      width={"100%"}
      bg={"$color3"}
      borderWidth={"$0.5"}
      borderColor={"$color8"}
    >
      <View
        height={250}
        width={"100%"}
        position={"relative"}
        group={true}
        cursor={"pointer"}
        overflow={"hidden"}
        onPress={handleImagePress}
      >
        <Image
          source={previewEventImage ? { uri: previewEventImage } : images.eventPlaceholder}
          width={"100%"}
          height={250}
          objectFit="cover"
          $group-hover={{
            scale: 1.01
          }}
          transition={"transform 0.2s ease-in-out"}
        />
        <YStack
          gap={"$3"}
          justify={"flex-start"}
          position={"absolute"}
          b={0}
          l={0}
          width={"100%"}
          p={"$4"}
          bg={"rgba(0, 0, 0, 0.2)"}
          backdropFilter={"blur(8px)"}
        >
          <H5>{localEvent.name}</H5>
          <XStack gap={"$4"}>
            <Badge>
              <XStack gap={"$2"}>
                <Calendar
                  size={16}
                  color={"$color1"}
                />
                {/* <Text fontSize={"$3"}>{formatDateToLongString(event.on)}</Text> */}
              </XStack>
            </Badge>
            <Badge>
              <XStack gap={"$2"}>
                <Clock
                  size={16}
                  color={"$color1"}
                />
                <Badge.Text fontSize={"$3"}>{/* {event.timing.startTime} - {event.timing.endTime} */}</Badge.Text>
              </XStack>
            </Badge>
          </XStack>
        </YStack>
      </View>

      <YStack
        gap={"$4"}
        p={"$4"}
        pt={0}
      >
        <XStack
          items={"center"}
          gap={"$2"}
          group={true}
          cursor={"pointer"}
        >
          <View
            bg={"$color1"}
            rounded={"$12"}
            width={"$3"}
            height={"$3"}
            justify={"center"}
            items={"center"}
            $group-hover={{
              bg: "$color12"
            }}
            transition={"background-color 0.2s ease-in-out"}
          >
            <MapPin
              size={16}
              color={"$color12"}
              $group-hover={{
                color: "$color1"
              }}
              transition={"color 0.2s ease-in-out"}
            />
          </View>
          <Text fontSize={"$4"}>{localEvent.location.street || "data not available"}</Text>
        </XStack>

        <XStack
          flex={+(typeof localEvent.capacity === "number")}
          justify={"space-between"}
        >
          {/* organizer info */}
          <ProfileAvatarPreview user={createdBy}>
            <IdentityCard
              imageUrl={createdBy.profilePic?.url || ""}
              title={createdBy.name}
              subtitle={createdBy.username ? `@${createdBy.username}` : ""}
            />
          </ProfileAvatarPreview>

          {/* capacity info */}
          {typeof localEvent.capacity === "number" && (
            <XStack
              items={"center"}
              justify={"flex-end"}
              gap={"$3"}
            >
              <YStack>
                <Text fontSize={"$3"}>Capacity</Text>
                <Text
                  fontSize={"$4"}
                  fontWeight={"bold"}
                >
                  {localEvent.capacity}
                </Text>
              </YStack>
              <CircularFillIndicator
                percentage={localEvent.participants.length / localEvent.capacity}
                size={30}
              />
            </XStack>
          )}
        </XStack>

        {/* verifiers */}
        <YStack
          gap={"$2"}
          items={"flex-start"}
        >
          <Text fontSize={"$3"}>Verifiers</Text>
          <XStack
            gap={"$2"}
            width={"100%"}
            justify={"space-between"}
            items={"center"}
          >
            {!!localEvent.verifiers.length ? (
              <UserCluster users={localEvent.verifiers.map((verifier) => verifier.user as IBaseUser)} />
            ) : (
              <Text
                fontSize={"$2"}
                color={"$color11"}
              >
                No verifiers yet
              </Text>
            )}

            <VerifyEvent
              event={localEvent}
              onVerified={(v) =>
                setLocalEvent((prev) => ({
                  ...prev,
                  verifiers: [...prev.verifiers, v]
                }))
              }
            />
          </XStack>
        </YStack>

        {!!localEvent.tags.length && (
          <ScrollView
            horizontal
            showsHorizontalScrollIndicator={false}
          >
            <XStack
              gap={"$2"}
              flexWrap={"wrap"}
            >
              {localEvent.tags.map((tag) => (
                <CustomTooltip
                  trigger={
                    <Badge
                      key={tag.id}
                      cursor="pointer"
                    >
                      <Badge.Text fontSize={"$3"}>{tag.name}</Badge.Text>
                    </Badge>
                  }
                  tooltipConfig={{ offset: 20 }}
                  key={tag.id}
                >
                  <TagPreviewTooltip tag={tag} />
                </CustomTooltip>
              ))}
            </XStack>
          </ScrollView>
        )}
        <FilledButton size={"medium"}>Join Event</FilledButton>
      </YStack>
    </YStack>
  );
};

const HomeScreen = () => {
  const toastController = useToastController();


  const fetchEvents = async () => {
    try {
      const response = await getAllEvents();
      return response;
    } catch (error: any) {
      toastController.show(error?.message || "Failed to fetch events");
    }
  };

  const { data: paginatedEvents, loading, error, setData } = useDataLoader({ promiseFunction: fetchEvents });
  const socket = useSocket();

  useEffect(() => {
    if (!socket) return;
    socket.on(PLATFORM_SOCKET_EVENTS.EVENT_CREATED, ({ data }) => {
      if (!data) return;
      setData((prev) => {
        if (!prev?.data) return prev;
        return {
          ...prev,
          data: {
            ...prev.data,
            items: [data, ...(prev.data.items || [])]
          }
        };
      });
    });

    socket.on(PLATFORM_SOCKET_EVENTS.EVENT_UPDATED, ({ data }) => {
      if (!data) return;
      setData((prev) => {
        if (!prev?.data) return prev;
        return {
          ...prev,
          data: {
            ...prev.data,
            items: prev.data.items.map((e) => (e.id === data.id ? data : e))
          }
        };
      });
    });

    socket.on(PLATFORM_SOCKET_EVENTS.EVENT_DELETED, ({ data }) => {
      if (!data) return;
      setData((prev) => {
        if (!prev?.data) return prev;
        return {
          ...prev,
          data: {
            ...prev.data,
            items: prev.data.items.filter((e) => e.id !== data.id)
          }
        };
      });
    });
  }, [socket]);

  if (loading) return <FullSizeLoader />;

  return (
    <>
      <ScrollView>
        <YStack
          bg="$background"
          width="100%"
          items={"center"}
          p={"$4"}
          gap={"$4"}
          maxW={600}
          scrollbarWidth="none"
          mx={"auto"}
        >
          {/* Search Button */}
          

          {paginatedEvents?.data?.items?.map((event) => (
            <EventCard
              key={event.id}
              event={event}
            />
          ))}
        </YStack>
      </ScrollView>

      
    </>
  );
};

export default HomeScreen;
