import CustomAvatar from "@/components/CustomAvatar";
import HorizontalTabs from "@/components/CustomTabs";
import { InputGroup } from "@/components/Form";
import PulsatingDot from "@/components/PulsatingDot";
import { Badge } from "@/components/ui/Badge";
import { OutlineButton } from "@/components/ui/Buttons";
import { IdentityCard, TagListing, UserCluster } from "@/components/ui/common-components";
import { CardWrapper, CircleBgWrapper } from "@/components/ui/common-styles";
import { SpinningLoader } from "@/components/ui/Loaders";
import { PLATFORM_SOCKET_EVENTS } from "@/constants/global";
import { useSocket } from "@/contexts/Socket";
import { IAddress, IBaseUser, ITag, ISearchResult, ISearchFilters } from "@/definitions/types";
import { formatDistance } from "@/helpers";
import { isEmpty, kebabCase, startCase } from "@/utils";
import { formatDateWithTimeString } from "@/utils/date.utils";
import { askForLocation, haversineDistanceInM } from "@/utils/location";
import { search, getSearchSuggestions, getSearchOptions } from "@/common/api/search.action";
import {
  ArrowRight,
  Clapperboard,
  CloudSun,
  Flame,
  Heart,
  MapPin,
  Menu,
  MessageCircle,
  Moon,
  RotateCcw,
  Search,
  Sun,
  Users,
  X,
  Filter,
  Calendar,
  User,
  Tag
} from "@tamagui/lucide-icons";
import { useToastController } from "@tamagui/toast";
import { LocationObjectCoords } from "expo-location";
import React, { useEffect, useState, useCallback } from "react";
import { useForm } from "react-hook-form";
import { H6, Image, ScrollView, Text, View, XStack, YStack, Button, Sheet, AnimatePresence, Input } from "tamagui";
import ExploreAssetPreview from "@/components/ExploreAssetPreview";
import { useDebounce } from "tamagui";
import { formatDistanceToNow } from "date-fns";

export enum EExploreComponents {
  TasteCalendar = "taste-calendar",
  FoodieFeed = "foodie-feed",
  Reels = "reels",
  Collaborations = "collaborations",
  Trending = "trending"
}

interface BasePayload {
  id: string;
  title: string;
  media: {
    type: string;
    url: string;
    thumbnailUrl: string;
  };
  location: IAddress;
  startTime: string;
  endTime: string;
  tags: ITag[];
  creator: IBaseUser;
  createdAt: string;
  status: string;
}

interface ITasteCalendarPayload extends BasePayload {
  filter: string[];
}

type IFoodieFeedPayload = BasePayload[];

interface IReelsPayload extends BasePayload {
  likes: number;
  comments: number;
  user: IBaseUser;
}

interface ICollaborationsPayload extends BasePayload {
  chef: string;
  time: string;
  going: number;
  verifiers: {
    user: IBaseUser;
    verifiedAt: string;
  }[];
}

interface ITrendingPayload extends BasePayload {
  going: number;
  verifiers: {
    user: IBaseUser;
    verifiedAt: string;
  }[];
}

interface IExploreSection {
  component: EExploreComponents;
  title: string;
  subtitle: string;
  payload: ITasteCalendarPayload | IFoodieFeedPayload | IReelsPayload | ICollaborationsPayload | ITrendingPayload;
}

const EventCard = ({ event, width = 140, children }: { event: any; width?: number; children?: React.ReactNode }) => {
  const startTime = event.startTime
    ? new Date(event.startTime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    : "";
  const endTime = event.endTime
    ? new Date(event.endTime).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    : "";

  return (
    <CardWrapper
      width={width}
      rounded="$4"
      overflow="hidden"
      p={0}
      cursor="pointer"
      position="relative"
    >
      <YStack
        height={100}
        bg="$color10"
      >
        <Image
          source={{ uri: event.image }}
          style={{ width: "100%", height: "100%" }}
          objectFit="cover"
        />
        <YStack
          position="absolute"
          b={0}
          l={0}
          r={0}
          p="$2"
        >
          <Text
            color="white"
            fontSize={"$1"}
          >
            {startTime} - {endTime}
          </Text>
        </YStack>
      </YStack>
      <YStack p="$2">
        <Text
          fontSize="$2"
          fontWeight="500"
          ellipsizeMode="tail"
          textOverflow="ellipsis"
          numberOfLines={1}
        >
          {event.title}
        </Text>
        <XStack
          items="center"
          gap="$1"
          mt="$1"
        >
          <MapPin size={12} />
          <Text
            fontSize={"$1"}
            color="$color10"
            ellipsizeMode="tail"
          >
            {event.location?.city} | {event.location?.country}
          </Text>
        </XStack>
      </YStack>
      {children}
    </CardWrapper>
  );
};

const CommonHeader = ({
  heading,
  subHeading,
  handleSeeAllPress
}: {
  heading: string;
  subHeading: string;
  handleSeeAllPress: () => void;
}) => {
  return (
    <XStack
      gap={"$4"}
      items={"flex-start"}
      justify={"space-between"}
      width={"100%"}
    >
      <YStack gap={"$1"}>
        <H6>{heading}</H6>
        <Text
          fontSize={"$2"}
          color={"$color10"}
        >
          {subHeading}
        </Text>
      </YStack>

      <XStack
        onPress={handleSeeAllPress}
        group
        gap={"$1"}
        items={"center"}
        flex={1}
        justify={"flex-end"}
      >
        <Text
          fontSize={"$3"}
          cursor="pointer"
        >
          See all
        </Text>
        <ArrowRight
          cursor="pointer"
          size={16}
          animation={"quick"}
          $group-hover={{
            transform: [{ translateX: 2 }]
          }}
        />
      </XStack>
    </XStack>
  );
};

const TasteCalendar = ({ payload, filters, userLocation }: { payload: ITasteCalendarPayload[]; filters: string[]; userLocation: LocationObjectCoords | null }) => {
  const iconMapping = {
    morning: <Sun size={16} />,
    evening: <CloudSun size={16} />,
    night: <Moon size={16} />
  };

  const renderTabContent = (filter: string) => {
    const filteredPayload = payload.filter((item) => item.filter.includes(filter));

    if (isEmpty(filteredPayload)) {
      return (
        <YStack
          height={150}
          justify={"center"}
          items={"center"}
          width={"100%"}
          flex={1}
        >
          <Text>No events found</Text>
        </YStack>
      );
    }

    return (
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
      >
        <XStack
          gap={"$2"}
          flexDirection="row"
        >
          {filteredPayload.map((item) => (
            <View key={item.id} width={140}>
              <ExploreAssetPreview
                media={item.media}
                title={item.title}
                location={item.location}
                creator={item.creator}
                createdAt={item.createdAt}
                startTime={item.startTime}
                endTime={item.endTime}
                userLocation={userLocation}
                tags={item.tags}
                showPreviewButton={true}
                previewButtonText="View"
              />
            </View>
          ))}
        </XStack>
      </ScrollView>
    );
  };

  const tabs = filters.map((filter) => ({
    label: startCase(filter),
    icon: iconMapping[filter as keyof typeof iconMapping],
    content: renderTabContent(filter)
  }));

  return (
    <XStack
      justify={"center"}
      flex={1}
    >
      <HorizontalTabs
        tabs={tabs}
        defaultValue={kebabCase(tabs[0].label)}
      />
    </XStack>
  );
};

const FoodieFeed = ({
  payload,
  userLocation
}: {
  payload: IFoodieFeedPayload;
  userLocation: LocationObjectCoords | null;
}) => {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
    >
      <XStack gap={"$4"}>
        {payload.map((item) => (
          <View key={item.id} width={150}>
            <ExploreAssetPreview
              media={item.media}
              title={item.title}
              location={item.location}
              creator={item.creator}
              createdAt={item.createdAt}
              startTime={item.startTime}
              endTime={item.endTime}
              userLocation={userLocation}
              tags={item.tags}
              showPreviewButton={true}
              previewButtonText="Live"
            />
          </View>
        ))}
      </XStack>
    </ScrollView>
  );
};

const Reels = ({ payload, userLocation }: { payload: IReelsPayload[]; userLocation: LocationObjectCoords | null }) => {
  return (
    <ScrollView>
      <XStack gap={"$4"}>
        {payload.map((item) => (
          <View key={item.id} width={160}>
            <ExploreAssetPreview
              media={item.media}
              title={item.title}
              location={item.location}
              creator={item.user}
              createdAt={item.createdAt}
              likes={item.likes}
              comments={item.comments}
              userLocation={userLocation}
              tags={item.tags}
              showPreviewButton={true}
              previewButtonText="Watch"
            />
          </View>
        ))}
      </XStack>
    </ScrollView>
  );
};

const Collaborations = ({
  payload,
  userLocation
}: {
  payload: ICollaborationsPayload[];
  userLocation: LocationObjectCoords | null;
}) => {
  return (
    <ScrollView>
      <YStack gap={"$4"}>
        {payload.map((item) => (
          <View key={item.id}>
            <ExploreAssetPreview
              media={item.media}
              title={item.title}
              location={item.location}
              creator={item.creator}
              createdAt={item.createdAt}
              startTime={item.startTime}
              endTime={item.endTime}
              going={item.going}
              userLocation={userLocation}
              tags={item.tags}
              showPreviewButton={true}
              previewButtonText="View Event"
            />
          </View>
        ))}
      </YStack>
    </ScrollView>
  );
};

const Trending = ({ payload, userLocation }: { payload: ITrendingPayload[]; userLocation: LocationObjectCoords | null }) => {
  return (
    <ScrollView>
      <XStack gap={"$4"}>
        {payload.map((item) => (
          <View key={item.id} width={180}>
            <ExploreAssetPreview
              media={item.media}
              title={item.title}
              location={item.location}
              creator={item.creator}
              createdAt={item.createdAt}
              startTime={item.startTime}
              endTime={item.endTime}
              going={item.going}
              userLocation={userLocation}
              tags={item.tags}
              showPreviewButton={true}
              previewButtonText="Trending"
            />
          </View>
        ))}
      </XStack>
    </ScrollView>
  );
};

const mapping = {
  [EExploreComponents.TasteCalendar]: {
    title: "Taste Calendar",
    subtitle: "Discover food events by time of day",
    component: TasteCalendar,
    filters: ["morning", "evening", "night"]
  },
  [EExploreComponents.FoodieFeed]: {
    title: "Foodie Feed",
    subtitle: "Live events happening now",
    component: FoodieFeed
  },
  [EExploreComponents.Reels]: {
    title: "Food Reels",
    subtitle: "Watch latest event highlights",
    component: Reels
  },
  [EExploreComponents.Collaborations]: {
    title: "Collaborations",
    subtitle: "Special events with chefs & influencers",
    component: Collaborations
  },
  [EExploreComponents.Trending]: {
    title: "Trending",
    subtitle: "Popular events in your area",
    component: Trending
  }
};

const explore = () => {
  const {
    control,
    formState: { errors },
    watch,
    setValue
  } = useForm({});

  const socket = useSocket();
  const searchQuery = watch("search");

  // Search state
  const [searchResults, setSearchResults] = useState<ISearchResult[]>([]);
  const [searchSuggestions, setSearchSuggestions] = useState<string[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [showSearchModal, setShowSearchModal] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [searchFilters, setSearchFilters] = useState<ISearchFilters>({});
  const [searchOptions, setSearchOptions] = useState<any>(null);
  const [searchPagination, setSearchPagination] = useState({
    total: 0,
    page: 1,
    limit: 20,
    hasNext: false,
  });

  const [currentUserLocation, setCurrentUserLocation] = useState<LocationObjectCoords | null>(null);
  const toastController = useToastController();
  const [sections, setSections] = useState<IExploreSection[]>([]);

  // Debounced search function
  const debouncedSearch = useDebounce(async (query: string) => {
    if (!query || query.length < 2) {
      setSearchResults([]);
      setShowSuggestions(false);
      return;
    }

    try {
      setIsSearching(true);
      const response = await search(query, searchFilters, 1, 20);
      if (response.success) {
        setSearchResults(response.data);
        setSearchPagination(response.pagination);
        setShowSearchModal(true);
      }
    } catch (error) {
      console.error('Search error:', error);
      toastController.show("Search failed. Please try again.");
    } finally {
      setIsSearching(false);
    }
  }, 500);

  // Debounced suggestions function
  const debouncedSuggestions = useDebounce(async (query: string) => {
    if (!query || query.length < 2) {
      setSearchSuggestions([]);
      setShowSuggestions(false);
      return;
    }

    try {
      const response = await getSearchSuggestions(query, 5);
      if (response.success) {
        setSearchSuggestions(response.data);
        setShowSuggestions(true);
      }
    } catch (error) {
      console.error('Suggestions error:', error);
    }
  }, 300);

  // Load search options
  useEffect(() => {
    const loadSearchOptions = async () => {
      try {
        const response = await getSearchOptions();
        if (response.success) {
          setSearchOptions(response.data);
        }
      } catch (error) {
        console.error('Error loading search options:', error);
      }
    };
    loadSearchOptions();
  }, []);

  // Handle search query changes
  useEffect(() => {
    if (searchQuery) {
      debouncedSuggestions(searchQuery);
    } else {
      setSearchSuggestions([]);
      setShowSuggestions(false);
    }
  }, [searchQuery]);

  const handleSearch = useCallback(() => {
    if (searchQuery && searchQuery.length >= 2) {
      debouncedSearch(searchQuery);
    }
  }, [searchQuery]);

  const handleSuggestionClick = (suggestion: string) => {
    setValue("search", suggestion);
    debouncedSearch(suggestion);
    setShowSuggestions(false);
  };

  const handleClearSearch = () => {
    setValue("search", "");
    setSearchResults([]);
    setShowSuggestions(false);
    setShowSearchModal(false);
  };

  const handleFilterPress = () => {
    // Toggle search filters
    console.log("filter pressed");
  };

  const handleResultClick = (result: ISearchResult) => {
    // Navigate to the appropriate screen based on result type
    switch (result.type) {
      case 'event':
        // Navigate to event details
        console.log('Navigate to event:', result.id);
        break;
      case 'user':
        // Navigate to user profile
        router.push(`/profile/${result.username || result.id}`);
        break;
      case 'tag':
        // Navigate to tag page
        console.log('Navigate to tag:', result.id);
        break;
    }
    setShowSearchModal(false);
  };

  const getResultIcon = (type: string) => {
    switch (type) {
      case 'event':
        return <Calendar size={16} color="$blue10" />;
      case 'user':
        return <User size={16} color="$green10" />;
      case 'tag':
        return <Tag size={16} color="$orange10" />;
      default:
        return null;
    }
  };

  const getResultBadgeColor = (type: string) => {
    switch (type) {
      case 'event':
        return '$blue5';
      case 'user':
        return '$green5';
      case 'tag':
        return '$orange5';
      default:
        return '$gray5';
    }
  };

  useEffect(() => {
    handleLocationAccess();
  }, []);

  useEffect(() => {
    if (!currentUserLocation) return;

    socket.emit(PLATFORM_SOCKET_EVENTS.EXPLORE, {
      filter: {
        location: {
          latitude: currentUserLocation?.latitude,
          longitude: currentUserLocation?.longitude
        }
      }
    });

    socket.on(PLATFORM_SOCKET_EVENTS.EXPLORE, ({ data, error }) => {
      console.log("data", data);
      if (error) {
        toastController.show(error);
      } else {
        setSections((prev) => [...prev, data]);
      }
    });
  }, [!!currentUserLocation, socket]);

  function handleLocationAccess() {
    askForLocation().then((location) => {
      if (location) {
        setCurrentUserLocation(location.coords);
      } else {
        toastController.show("Failed to get your location");
      }
    });
  }

  if (!currentUserLocation) {
    return (
      <YStack
        flex={1}
        justify={"center"}
        items={"center"}
        gap={"$4"}
      >
        <Text
          maxW={400}
          text={"center"}
        >
          Oh no! We need your location to create your personalized feed.
        </Text>
        <OutlineButton
          onPress={handleLocationAccess}
          icon={<RotateCcw size={16} />}
        >
          <Text>Allow location access</Text>
        </OutlineButton>
      </YStack>
    );
  }

  return (
    <>
      <YStack
        gap={"$4"}
        p={"$4"}
        width={"100%"}
        flex={1}
      >
        <YStack position="relative">
          <InputGroup
            control={control}
            name="search"
            placeHolder="Search for events, users, tags..."
            error={errors.search?.message}
            iconBefore={<Search size={16} />}
            iconAfter={
              <XStack gap="$2">
                {searchQuery && (
                  <Button
                    size="$2"
                    circular
                    backgroundColor="transparent"
                    onPress={handleClearSearch}
                    icon={X}
                    color="$gray10"
                  />
                )}
                <Button
                  size="$2"
                  circular
                  backgroundColor={Object.keys(searchFilters).length > 0 ? "$blue10" : "transparent"}
                  onPress={handleFilterPress}
                  icon={Filter}
                  color={Object.keys(searchFilters).length > 0 ? "white" : "$gray10"}
                />
              </XStack>
            }
            onChange={(value) => {
              // Handle search on Enter key (if we can detect it)
              // For now, we'll trigger search when user types and stops
              if (value && value.length >= 2) {
                // Auto-search after typing
                debouncedSearch(value);
              }
            }}
          />

          {/* Search Suggestions */}
          <AnimatePresence>
            {showSuggestions && searchSuggestions.length > 0 && (
              <YStack
                position="absolute"
                top="100%"
                left={0}
                right={0}
                backgroundColor="$background"
                borderRadius="$3"
                borderWidth={1}
                borderColor="$borderColor"
                shadowColor="$shadowColor"
                shadowOffset={{ width: 0, height: 4 }}
                shadowOpacity={0.1}
                shadowRadius={8}
                elevation={8}
                zIndex={1000}
                marginTop="$1"
                maxHeight={200}
                overflow="hidden"
                enterStyle={{ opacity: 0, scale: 0.95, y: -10 }}
                exitStyle={{ opacity: 0, scale: 0.95, y: -10 }}
                animation="quick"
              >
                {searchSuggestions.map((suggestion, index) => (
                  <Button
                    key={index}
                    backgroundColor="transparent"
                    borderWidth={0}
                    borderRadius={0}
                    paddingHorizontal="$3"
                    paddingVertical="$2"
                    justifyContent="flex-start"
                    onPress={() => handleSuggestionClick(suggestion)}
                    hoverStyle={{ backgroundColor: "$gray5" }}
                    pressStyle={{ backgroundColor: "$gray6" }}
                  >
                    <Text
                      fontSize="$3"
                      color="$color"
                      numberOfLines={1}
                      ellipsizeMode="tail"
                    >
                      {suggestion}
                    </Text>
                  </Button>
                ))}
              </YStack>
            )}
          </AnimatePresence>
        </YStack>

        {!sections.length ? (
          <YStack
            flex={1}
            justify={"center"}
            items={"center"}
          >
            <SpinningLoader />
          </YStack>
        ) : (
          <ScrollView flex={1}>
            <YStack gap={"$5"}>
              {sections.map((section) => {
                if (section.component in mapping) {
                  const Component = mapping[section.component].component;
                  return (
                    <YStack gap={"$3"}>
                      <CommonHeader
                        heading={section.title}
                        subHeading={section.subtitle}
                        handleSeeAllPress={() => {}}
                      />
                      <Component
                        payload={section.payload as any}
                        userLocation={currentUserLocation}
                        filters={(mapping[section.component] as any)?.filters || []}
                      />
                    </YStack>
                  );
                }
                return null;
              })}
            </YStack>
          </ScrollView>
        )}
      </YStack>

      {/* Search Results Modal */}
      <Sheet
        modal
        open={showSearchModal}
        onOpenChange={setShowSearchModal}
        snapPoints={[85]}
        position={0}
        dismissOnSnapToBottom
      >
        <Sheet.Overlay
          animation="lazy"
          enterStyle={{ opacity: 0 }}
          exitStyle={{ opacity: 0 }}
        />
        <Sheet.Frame
          padding="$4"
          justifyContent="flex-start"
          alignItems="center"
          space="$4"
        >
          <Sheet.Handle />

          <XStack width="100%" alignItems="center" justifyContent="space-between">
            <H6>Search Results</H6>
            <Button
              size="$2"
              circular
              backgroundColor="transparent"
              onPress={() => setShowSearchModal(false)}
              icon={X}
              color="$gray10"
            />
          </XStack>

          <ScrollView width="100%" flex={1}>
            {isSearching ? (
              <YStack alignItems="center" justifyContent="center" padding="$8">
                <SpinningLoader />
                <Text marginTop="$3" color="$gray10">Searching...</Text>
              </YStack>
            ) : searchResults.length > 0 ? (
              <YStack gap="$1">
                <XStack alignItems="center" justifyContent="space-between" paddingHorizontal="$4">
                  <Text fontSize="$3" color="$gray10">
                    {searchPagination.total} results found
                  </Text>
                </XStack>

                {searchResults.map((result) => (
                  <Button
                    key={`${result.type}-${result.id}`}
                    backgroundColor="transparent"
                    borderWidth={0}
                    paddingHorizontal="$4"
                    paddingVertical="$3"
                    onPress={() => handleResultClick(result)}
                    hoverStyle={{ backgroundColor: "$gray5" }}
                    pressStyle={{ backgroundColor: "$gray6" }}
                  >
                    <XStack gap="$3" alignItems="center" width="100%">
                      <YStack width={50} height={50} borderRadius="$3" overflow="hidden">
                        {result.imageUrl ? (
                          <Image
                            source={{ uri: result.imageUrl }}
                            width="100%"
                            height="100%"
                            resizeMode="cover"
                          />
                        ) : (
                          <YStack
                            width="100%"
                            height="100%"
                            backgroundColor="$gray5"
                            alignItems="center"
                            justifyContent="center"
                          >
                            {getResultIcon(result.type)}
                          </YStack>
                        )}
                      </YStack>

                      <YStack flex={1} gap="$1">
                        <XStack alignItems="center" gap="$2">
                          <Badge backgroundColor={getResultBadgeColor(result.type)}>
                            <Badge.Text fontSize="$2" textTransform="capitalize">
                              {result.type}
                            </Badge.Text>
                          </Badge>
                          <H6 flex={1} numberOfLines={1} ellipsizeMode="tail">
                            {result.title}
                          </H6>
                        </XStack>

                        {result.description && (
                          <Text
                            fontSize="$3"
                            color="$gray10"
                            numberOfLines={2}
                            ellipsizeMode="tail"
                          >
                            {result.description}
                          </Text>
                        )}

                        <XStack gap="$3" alignItems="center">
                          <Text fontSize="$2" color="$gray8">
                            {formatDistanceToNow(new Date(result.createdAt), { addSuffix: true })}
                          </Text>

                          {result.type === 'event' && result.metadata?.location && (
                            <XStack alignItems="center" gap="$1">
                              <MapPin size={12} color="$gray8" />
                              <Text fontSize="$2" color="$gray8">
                                {result.metadata.location.city || result.metadata.location.place}
                              </Text>
                            </XStack>
                          )}

                          {result.type === 'event' && result.metadata?.participants && (
                            <XStack alignItems="center" gap="$1">
                              <Users size={12} color="$gray8" />
                              <Text fontSize="$2" color="$gray8">
                                {result.metadata.participants} participants
                              </Text>
                            </XStack>
                          )}
                        </XStack>
                      </YStack>
                    </XStack>
                  </Button>
                ))}
              </YStack>
            ) : searchQuery ? (
              <YStack alignItems="center" justifyContent="center" padding="$8">
                <Text color="$gray10" textAlign="center">
                  No results found for "{searchQuery}"
                </Text>
                <Text fontSize="$3" color="$gray8" textAlign="center" marginTop="$2">
                  Try adjusting your search terms or filters
                </Text>
              </YStack>
            ) : (
              <YStack alignItems="center" justifyContent="center" padding="$8">
                <Text color="$gray10" textAlign="center">
                  Start typing to search for events, users, and tags
                </Text>
              </YStack>
            )}
          </ScrollView>
        </Sheet.Frame>
      </Sheet>
    </>
  );
};

export default explore;
