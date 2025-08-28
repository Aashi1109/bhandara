import { CardWrapper } from "@/components/ui/common-styles";
import { Text, XStack, YStack, View, Button, ScrollView, Image } from "tamagui";
import { useAuth } from "@/contexts/AuthContext";
import { useDataLoader } from "@/hooks";
import { getUserEvents } from "@/common/api/events.action";
import { IEvent } from "@/definitions/types";
import { Badge } from "@/components/ui/Badge";
import { EEventStatus } from "@/definitions/enums";
import { Search, MapPin, Share2, QrCode, Clock, Calendar } from "@tamagui/lucide-icons";
import { formatDateRange } from "@/utils/date.utils";

const ActivityTabContent = () => {
  const { user } = useAuth();
  const { data } = useDataLoader({
    promiseFunction: () => getUserEvents(user!.id),
    enabled: !!user
  });

  const events = data?.data?.items || [];

  // Group events by date
  const groupEventsByDate = (events: IEvent[]) => {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const grouped = {
      now: [] as IEvent[],
      upcoming: [] as IEvent[],
      past: [] as IEvent[]
    };

    events.forEach((event) => {
      const eventDate = new Date(event.timings.start);
      const eventDay = new Date(eventDate.getFullYear(), eventDate.getMonth(), eventDate.getDate());

      if (eventDay.getTime() === today.getTime()) {
        grouped.now.push(event);
      } else if (eventDay.getTime() > today.getTime()) {
        grouped.upcoming.push(event);
      } else if (eventDay.getTime() < today.getTime()) {
        grouped.past.push(event);
      }
    });

    return grouped;
  };

  const groupedEvents = groupEventsByDate(events);

  const getEventImage = (event: IEvent) => {
    return event.media?.[0]?.url || "https://via.placeholder.com/300x200/4A90E2/FFFFFF?text=Event";
  };

  const getEventIcon = (event: IEvent) => {
    // You can customize this based on event tags or type
    return "🍽️"; // Default food icon
  };

  const formatEventTime = (event: IEvent) => {
    const { timeRange } = formatDateRange(event.timings.start, event.timings.end);
    return timeRange;
  };

  const formatEventDate = (event: IEvent) => {
    const date = new Date(event.timings.start);
    return date.toLocaleDateString("en-US", {
      day: "numeric",
      month: "short"
    });
  };

  return (
    <YStack
      flex={1}
      bg="$background"
      p="$4"
      gap="$4"
    >
      {/* Search and Filter Section */}
      <XStack
        gap="$3"
        items="center"
      >
        <Button
          size="$3"
          circular
          bg="$color1"
          borderColor="$color3"
          borderWidth={1}
          onPress={() => {}}
        >
          <Search
            size={16}
            color="$color11"
          />
        </Button>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
        >
          <XStack gap="$2">
            <Button
              size="$2"
              bg="$color2"
              borderColor="$color3"
              borderWidth={1}
              rounded="$4"
              onPress={() => {}}
            >
              <Text
                fontSize="$2"
                color="$color11"
              >
                Food 🌭
              </Text>
              <Text
                fontSize="$2"
                color="$color11"
                ml="$1"
              >
                ×
              </Text>
            </Button>
            <Button
              size="$2"
              bg="$color2"
              borderColor="$color3"
              borderWidth={1}
              rounded="$4"
              onPress={() => {}}
            >
              <Text
                fontSize="$2"
                color="$color11"
              >
                Sport 💪
              </Text>
              <Text
                fontSize="$2"
                color="$color11"
                ml="$1"
              >
                ×
              </Text>
            </Button>
            <Button
              size="$2"
              bg="$color2"
              borderColor="$color3"
              borderWidth={1}
              rounded="$4"
              onPress={() => {}}
            >
              <Text
                fontSize="$2"
                color="$color11"
              >
                Orchestra 🎻
              </Text>
              <Text
                fontSize="$2"
                color="$color11"
                ml="$1"
              >
                ×
              </Text>
            </Button>
          </XStack>
        </ScrollView>
      </XStack>

      {/* Events List */}
      <ScrollView
        flex={1}
        showsVerticalScrollIndicator={false}
      >
        <YStack gap="$4">
          {/* NOW Section */}
          {groupedEvents.now.length > 0 && (
            <YStack gap="$3">
              <Button
                size="$2"
                bg="$red10"
                color="white"
                rounded="$4"
                self="flex-start"
                disabled
              >
                <Text
                  color="white"
                  fontWeight="600"
                >
                  NOW
                </Text>
              </Button>

              {groupedEvents.now.map((event) => (
                <CardWrapper
                  key={event.id}
                  p="$0"
                  overflow="hidden"
                >
                  <View position="relative">
                    <Image
                      source={{ uri: getEventImage(event) }}
                      width="100%"
                      height={200}
                      resizeMode="cover"
                    />
                    <View
                      position="absolute"
                      t="$3"
                      l="$3"
                      flexDirection="row"
                      items="center"
                      gap="$2"
                    >
                      <View
                        bg="$yellow3"
                        rounded="$12"
                        width="$4"
                        height="$4"
                        items="center"
                        justify="center"
                      >
                        <Text fontSize="$1">🍽️</Text>
                      </View>
                      <View
                        bg="$color1"
                        rounded="$3"
                        px="$2"
                        py="$1"
                      >
                        <Text
                          fontSize="$2"
                          color="$color11"
                        >
                          {formatEventDate(event)}
                        </Text>
                      </View>
                    </View>
                    <View
                      position="absolute"
                      b="$3"
                      l="$3"
                      r="$3"
                    >
                      <Text
                        fontSize="$6"
                        fontWeight="600"
                        color="white"
                        textShadowColor="rgba(0,0,0,0.5)"
                        textShadowOffset={{ width: 0, height: 1 }}
                        textShadowRadius={2}
                      >
                        {event.name}
                      </Text>
                    </View>
                  </View>

                  <YStack
                    p="$3"
                    gap="$2"
                  >
                    <XStack
                      items="center"
                      gap="$2"
                    >
                      <MapPin
                        size={14}
                        color="$color10"
                      />
                      <Text
                        fontSize="$3"
                        color="$color11"
                        flex={1}
                      >
                        {event.location.address}
                      </Text>
                      <Button
                        size="$2"
                        circular
                        bg="$color2"
                        onPress={() => {}}
                      >
                        <Share2
                          size={14}
                          color="$color10"
                        />
                      </Button>
                    </XStack>
                  </YStack>
                </CardWrapper>
              ))}
            </YStack>
          )}

          {/* Upcoming Events Section */}
          {groupedEvents.upcoming.length > 0 && (
            <YStack gap="$3">
              <View
                bg="$color2"
                rounded="$3"
                px="$3"
                py="$1"
                self="flex-start"
              >
                <Text
                  fontSize="$3"
                  color="$color11"
                  fontWeight="500"
                >
                  {formatEventDate(groupedEvents.upcoming[0])}
                </Text>
              </View>

              {groupedEvents.upcoming.map((event) => (
                <CardWrapper
                  key={event.id}
                  p="$3"
                  gap="$3"
                >
                  <XStack
                    gap="$3"
                    items="center"
                  >
                    <View position="relative">
                      <Image
                        source={{ uri: getEventImage(event) }}
                        width={80}
                        height={80}
                        rounded="$3"
                        resizeMode="cover"
                      />
                      <View
                        position="absolute"
                        t="$1"
                        l="$1"
                        bg="$yellow3"
                        rounded="$12"
                        width="$3"
                        height="$3"
                        items="center"
                        justify="center"
                      >
                        <Text fontSize="$1">🍽️</Text>
                      </View>
                    </View>

                    <YStack
                      flex={1}
                      gap="$1"
                    >
                      <Text
                        fontSize="$4"
                        fontWeight="600"
                        numberOfLines={2}
                      >
                        {event.name}
                      </Text>
                      <XStack
                        items="center"
                        gap="$1"
                      >
                        <Clock
                          size={12}
                          color="$color10"
                        />
                        <Text
                          fontSize="$2"
                          color="$color11"
                        >
                          {formatEventTime(event)}
                        </Text>
                      </XStack>
                    </YStack>

                    <View
                      bg="$color2"
                      rounded="$12"
                      width="$6"
                      height="$6"
                      items="center"
                      justify="center"
                    >
                      <Text
                        fontSize="$2"
                        color="$color11"
                      >
                        {user?.name?.charAt(0) || "U"}
                      </Text>
                    </View>
                  </XStack>

                  <XStack
                    items="center"
                    gap="$2"
                  >
                    <MapPin
                      size={14}
                      color="$color10"
                    />
                    <Text
                      fontSize="$3"
                      color="$color11"
                      flex={1}
                    >
                      {event.location.address}
                    </Text>
                    <Button
                      size="$2"
                      circular
                      bg="$color2"
                      onPress={() => {}}
                    >
                      <Share2
                        size={14}
                        color="$color10"
                      />
                    </Button>
                    <Button
                      size="$2"
                      circular
                      bg="$color1"
                      onPress={() => {}}
                    >
                      <QrCode
                        size={14}
                        color="$color11"
                      />
                    </Button>
                  </XStack>
                </CardWrapper>
              ))}
            </YStack>
          )}

          {/* Past Events Section */}
          {groupedEvents.past.length > 0 && (
            <YStack gap="$3">
              <View
                bg="$color8"
                rounded="$3"
                px="$3"
                py="$1"
                self="flex-start"
              >
                <Text
                  fontSize="$3"
                  color="$color1"
                  fontWeight="500"
                >
                  Past Events
                </Text>
              </View>

              {groupedEvents.past.map((event) => (
                <CardWrapper
                  key={event.id}
                  p="$3"
                  gap="$3"
                  opacity={0.7}
                >
                  <XStack
                    gap="$3"
                    items="center"
                  >
                    <View position="relative">
                      <Image
                        source={{ uri: getEventImage(event) }}
                        width={80}
                        height={80}
                        rounded="$3"
                        resizeMode="cover"
                      />
                      <View
                        position="absolute"
                        t="$1"
                        l="$1"
                        bg="$color8"
                        rounded="$12"
                        width="$3"
                        height="$3"
                        items="center"
                        justify="center"
                      >
                        <Text fontSize="$1">🍽️</Text>
                      </View>
                    </View>

                    <YStack
                      flex={1}
                      gap="$1"
                    >
                      <Text
                        fontSize="$4"
                        fontWeight="600"
                        numberOfLines={2}
                        color="$color10"
                      >
                        {event.name}
                      </Text>
                      <XStack
                        items="center"
                        gap="$1"
                      >
                        <Clock
                          size={12}
                          color="$color8"
                        />
                        <Text
                          fontSize="$2"
                          color="$color8"
                        >
                          {formatEventTime(event)}
                        </Text>
                      </XStack>
                    </YStack>

                    <View
                      bg="$color8"
                      rounded="$12"
                      width="$6"
                      height="$6"
                      items="center"
                      justify="center"
                    >
                      <Text
                        fontSize="$2"
                        color="$color1"
                      >
                        {user?.name?.charAt(0) || "U"}
                      </Text>
                    </View>
                  </XStack>

                  <XStack
                    items="center"
                    gap="$2"
                  >
                    <MapPin
                      size={14}
                      color="$color8"
                    />
                    <Text
                      fontSize="$3"
                      color="$color8"
                      flex={1}
                    >
                      {event.location.address}
                    </Text>
                    <Button
                      size="$2"
                      circular
                      bg="$color8"
                      onPress={() => {}}
                    >
                      <Share2
                        size={14}
                        color="$color1"
                      />
                    </Button>
                  </XStack>
                </CardWrapper>
              ))}
            </YStack>
          )}

          {/* No Events State */}
          {groupedEvents.now.length === 0 && groupedEvents.upcoming.length === 0 && groupedEvents.past.length === 0 && (
            <YStack
              items="center"
              justify="center"
              py="$8"
            >
              <Calendar
                size={48}
                color="$color8"
              />
              <Text
                fontSize="$4"
                color="$color11"
                mt="$3"
                text="center"
              >
                No events found
              </Text>
              <Text
                fontSize="$3"
                color="$color10"
                text="center"
              >
                You haven't created any events yet
              </Text>
            </YStack>
          )}
        </YStack>
      </ScrollView>
    </YStack>
  );
};

export default ActivityTabContent;
