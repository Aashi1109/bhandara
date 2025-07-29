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
      upcoming: [] as IEvent[]
    };

    events.forEach(event => {
      const eventDate = new Date(event.timings.start);
      const eventDay = new Date(eventDate.getFullYear(), eventDate.getMonth(), eventDate.getDate());
      
      if (eventDay.getTime() === today.getTime()) {
        grouped.now.push(event);
      } else if (eventDay.getTime() === tomorrow.getTime()) {
        grouped.upcoming.push(event);
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
    <YStack flex={1} bg="$background" p="$4" gap="$4">
      {/* Search and Filter Section */}
      <XStack gap="$3" alignItems="center">
        <Button
          size="$3"
          circular
          bg="$gray1"
          borderColor="$gray3"
          borderWidth={1}
          onPress={() => {}}
        >
          <Search size={16} color="$gray11" />
        </Button>
        
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <XStack gap="$2">
            <Button
              size="$2"
              bg="$gray2"
              borderColor="$gray3"
              borderWidth={1}
              borderRadius="$4"
              onPress={() => {}}
            >
              <Text fontSize="$2" color="$gray11">Food 🌭</Text>
              <Text fontSize="$2" color="$gray11" ml="$1">×</Text>
            </Button>
            <Button
              size="$2"
              bg="$gray2"
              borderColor="$gray3"
              borderWidth={1}
              borderRadius="$4"
              onPress={() => {}}
            >
              <Text fontSize="$2" color="$gray11">Sport 💪</Text>
              <Text fontSize="$2" color="$gray11" ml="$1">×</Text>
            </Button>
            <Button
              size="$2"
              bg="$gray2"
              borderColor="$gray3"
              borderWidth={1}
              borderRadius="$4"
              onPress={() => {}}
            >
              <Text fontSize="$2" color="$gray11">Orchestra 🎻</Text>
              <Text fontSize="$2" color="$gray11" ml="$1">×</Text>
            </Button>
          </XStack>
        </ScrollView>
      </XStack>

      {/* Events List */}
      <ScrollView flex={1} showsVerticalScrollIndicator={false}>
        <YStack gap="$4">
          {/* NOW Section */}
          {groupedEvents.now.length > 0 && (
            <YStack gap="$3">
              <Button
                size="$2"
                bg="$red10"
                color="white"
                borderRadius="$4"
                alignSelf="flex-start"
                disabled
              >
                <Text color="white" fontWeight="600">NOW</Text>
              </Button>
              
              {groupedEvents.now.map((event) => (
                <CardWrapper key={event.id} p="$0" overflow="hidden">
                  <View position="relative">
                    <Image
                      source={{ uri: getEventImage(event) }}
                      width="100%"
                      height={200}
                      resizeMode="cover"
                    />
                    <View
                      position="absolute"
                      top="$3"
                      left="$3"
                      flexDirection="row"
                      alignItems="center"
                      gap="$2"
                    >
                      <View
                        bg="$yellow3"
                        borderRadius="$12"
                        width="$4"
                        height="$4"
                        alignItems="center"
                        justifyContent="center"
                      >
                        <Text fontSize="$1">🍽️</Text>
                      </View>
                      <View
                        bg="$gray1"
                        borderRadius="$3"
                        px="$2"
                        py="$1"
                      >
                        <Text fontSize="$2" color="$gray11">
                          {formatEventDate(event)}
                        </Text>
                      </View>
                    </View>
                    <View
                      position="absolute"
                      bottom="$3"
                      left="$3"
                      right="$3"
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
                  
                  <YStack p="$3" gap="$2">
                    <XStack alignItems="center" gap="$2">
                      <MapPin size={14} color="$gray10" />
                      <Text fontSize="$3" color="$gray11" flex={1}>
                        {event.location.address}
                      </Text>
                      <Button
                        size="$2"
                        circular
                        bg="$gray2"
                        onPress={() => {}}
                      >
                        <Share2 size={14} color="$gray10" />
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
                bg="$gray2"
                borderRadius="$3"
                px="$3"
                py="$1"
                alignSelf="flex-start"
              >
                <Text fontSize="$3" color="$gray11" fontWeight="500">
                  {formatEventDate(groupedEvents.upcoming[0])}
                </Text>
              </View>
              
              {groupedEvents.upcoming.map((event) => (
                <CardWrapper key={event.id} p="$3" gap="$3">
                  <XStack gap="$3" alignItems="center">
                    <View position="relative">
                      <Image
                        source={{ uri: getEventImage(event) }}
                        width={80}
                        height={80}
                        borderRadius="$3"
                        resizeMode="cover"
                      />
                      <View
                        position="absolute"
                        top="$1"
                        left="$1"
                        bg="$yellow3"
                        borderRadius="$12"
                        width="$3"
                        height="$3"
                        alignItems="center"
                        justifyContent="center"
                      >
                        <Text fontSize="$1">🍽️</Text>
                      </View>
                    </View>
                    
                    <YStack flex={1} gap="$1">
                      <Text fontSize="$4" fontWeight="600" numberOfLines={2}>
                        {event.name}
                      </Text>
                      <XStack alignItems="center" gap="$1">
                        <Clock size={12} color="$gray10" />
                        <Text fontSize="$2" color="$gray11">
                          {formatEventTime(event)}
                        </Text>
                      </XStack>
                    </YStack>
                    
                    <View
                      bg="$gray2"
                      borderRadius="$12"
                      width="$6"
                      height="$6"
                      alignItems="center"
                      justifyContent="center"
                    >
                      <Text fontSize="$2" color="$gray11">
                        {user?.name?.charAt(0) || "U"}
                      </Text>
                    </View>
                  </XStack>
                  
                  <XStack alignItems="center" gap="$2">
                    <MapPin size={14} color="$gray10" />
                    <Text fontSize="$3" color="$gray11" flex={1}>
                      {event.location.address}
                    </Text>
                    <Button
                      size="$2"
                      circular
                      bg="$gray2"
                      onPress={() => {}}
                    >
                      <Share2 size={14} color="$gray10" />
                    </Button>
                    <Button
                      size="$2"
                      circular
                      bg="$gray1"
                      onPress={() => {}}
                    >
                      <QrCode size={14} color="$gray11" />
                    </Button>
                  </XStack>
                </CardWrapper>
              ))}
            </YStack>
          )}

          {/* No Events State */}
          {events.length === 0 && (
            <YStack alignItems="center" justifyContent="center" py="$8">
              <Calendar size={48} color="$gray8" />
              <Text fontSize="$4" color="$gray11" mt="$3" textAlign="center">
                No events found
              </Text>
              <Text fontSize="$3" color="$gray10" textAlign="center">
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
