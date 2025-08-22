import React, { useState, useEffect } from "react";
import { useLocalSearchParams } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { 
  View, 
  Text, 
  ScrollView, 
  YStack, 
  XStack, 
  Image,
  LinearGradient,
  Card,
  Button,
  AnimatePresence,
  useTheme,
  Sheet,
  H1,
  H2,
  H3,
  H4,
  Paragraph,
  Stack,
  Circle
} from "tamagui";
import { 
  Calendar, 
  Clock, 
  Star, 
  Heart,
  Share2,
  MessageCircle,
  MapPin,
  Award,
  Users,
  ChevronLeft,
  Play,
  MoreHorizontal
} from "@tamagui/lucide-icons";
import { Dimensions, Pressable } from "react-native";
import { BlurView } from "expo-blur";
import PublicProfileHeader from "@/components/PublicProfile/PublicProfileHeader";
import PublicProfileStats from "@/components/PublicProfile/PublicProfileStats";
import PublicProfileTabs from "@/components/PublicProfile/PublicProfileTabs";
import PublicProfileGallery from "@/components/PublicProfile/PublicProfileGallery";
import PublicProfileSchedule from "@/components/PublicProfile/PublicProfileSchedule";
import PublicProfileFriends from "@/components/PublicProfile/PublicProfileFriends";
import { useRouter } from "expo-router";
import { getUserByUsername } from "@/common/api/user.action";
import { SpinningLoader } from "@/components/ui/Loaders";

const { width: screenWidth } = Dimensions.get("window");

export default function PublicProfileScreen() {
  const { username } = useLocalSearchParams<{ username: string }>();
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<any>(null);
  const [activeTab, setActiveTab] = useState("hello");
  const [showLightbox, setShowLightbox] = useState(false);
  const [selectedImage, setSelectedImage] = useState(null);
  const router = useRouter();
  const theme = useTheme();

  useEffect(() => {
    loadUserProfile();
  }, [username]);

  const loadUserProfile = async () => {
    try {
      setLoading(true);
      
      // Fetch actual user data
      const response = await getUserByUsername(username as string);
      if (response.data) {
        // Transform API data to match our UI structure
                const userData = response.data;
        const mockUser = {
          id: userData.id,
          username: userData.username,
          name: userData.name,
          bio: userData.bio || "Event Professional",
          profilePic: userData.profilePic?.url || userData.media?.url || "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400",
          coverImage: userData.coverImage?.url || "https://images.unsplash.com/photo-1519741497674-611481863552?w=800",
          experience: userData.experience || "Event Professional",
        stats: {
          eventsHosted: 25,
          totalHours: 210,
          reviews: 135,
          followers: 1240,
          likes: 3450
        },
        gallery: [
          { id: "1", url: "https://images.unsplash.com/photo-1519225421980-715cb0215aed?w=400", type: "image" },
          { id: "2", url: "https://images.unsplash.com/photo-1465495976277-4387d4b0b4c6?w=400", type: "image" },
          { id: "3", url: "https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=400", type: "video" },
          { id: "4", url: "https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=400", type: "image" },
          { id: "5", url: "https://images.unsplash.com/photo-1522673607200-164d1b6ce486?w=400", type: "image" },
          { id: "6", url: "https://images.unsplash.com/photo-1525253086316-d0c936c814f8?w=400", type: "image" }
        ],
        schedule: [
          { id: "1", day: "Mon", activities: [] },
          { id: "2", day: "Tue", activities: [
            { type: "Workshop", icon: "🎨", time: "10:00 - 12:00", location: "Design Studio" }
          ]},
          { id: "3", day: "Wed", activities: [
            { type: "Event Setup", icon: "🏗️", time: "08:00 - 14:00", location: "Grand Hotel" }
          ]},
          { id: "4", day: "Thu", activities: [] },
          { id: "5", day: "Fri", activities: [
            { type: "Wedding", icon: "💒", time: "15:00 - 23:00", location: "Beach Resort" }
          ]}
        ],
        friends: [
          { id: "1", name: "Sarah J.", avatar: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200" },
          { id: "2", name: "Mike D.", avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200" },
          { id: "3", name: "Emma W.", avatar: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200" }
        ]
      };
      setUser(mockUser);
      } else {
        setUser(null);
      }
    } catch (error) {
      console.error("Error loading profile:", error);
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View flex={1} bg="$background" ai="center" jc="center">
        <SpinningLoader size="large" />
      </View>
    );
  }

  if (!user) {
    return (
      <View flex={1} bg="$background" ai="center" jc="center" p="$4">
        <H3 color="$color11">User not found</H3>
        <Button mt="$4" onPress={() => router.back()}>Go Back</Button>
      </View>
    );
  }

  return (
    <View flex={1} bg="$background">
      <ScrollView 
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 100 }}
      >
        {/* Header Section */}
        <PublicProfileHeader user={user} onBack={() => router.back()} />

        {/* Stats Row */}
        <PublicProfileStats stats={user.stats} />

        {/* Tabbed Navigation */}
        <PublicProfileTabs 
          activeTab={activeTab} 
          onTabChange={setActiveTab}
        />

        {/* Tab Content */}
        <AnimatePresence>
          {activeTab === "hello" && (
            <View animation="fadeIn" p="$4">
              <YStack space="$4">
                <Card elevate bordered p="$4" backgroundColor="$color2">
                  <H3 mb="$2">About</H3>
                  <Paragraph color="$color11">
                    Passionate about creating unforgettable moments through beautiful floral designs 
                    and meticulous event styling. Specializing in luxury weddings and corporate events 
                    with a focus on sustainable practices and locally sourced materials.
                  </Paragraph>
                </Card>

                <Card elevate bordered p="$4" backgroundColor="$color2">
                  <H3 mb="$3">Specialties</H3>
                  <XStack flexWrap="wrap" gap="$2">
                    {["Weddings", "Corporate Events", "Floral Design", "Event Styling", "Sustainable Events"].map((tag) => (
                      <View 
                        key={tag} 
                        backgroundColor="$color4" 
                        px="$3" 
                        py="$1.5" 
                        borderRadius="$10"
                      >
                        <Text fontSize="$2" color="$color11">{tag}</Text>
                      </View>
                    ))}
                  </XStack>
                </Card>
              </YStack>
            </View>
          )}

          {activeTab === "stats" && (
            <View animation="fadeIn" p="$4">
              <PublicProfileStats stats={user.stats} detailed />
            </View>
          )}

          {activeTab === "photos" && (
            <View animation="fadeIn">
              <PublicProfileGallery 
                gallery={user.gallery} 
                onImagePress={(image) => {
                  setSelectedImage(image);
                  setShowLightbox(true);
                }}
              />
            </View>
          )}

          {activeTab === "schedule" && (
            <View animation="fadeIn" p="$4">
              <PublicProfileSchedule schedule={user.schedule} />
            </View>
          )}
        </AnimatePresence>

        {/* Friends/Collaborators Section */}
        <PublicProfileFriends friends={user.friends} />

      </ScrollView>

      {/* Floating Action Buttons */}
      <XStack 
        position="absolute" 
        bottom="$4" 
        left="$4" 
        right="$4"
        justifyContent="center"
        gap="$3"
      >
        <Button 
          size="$4"
          backgroundColor="$blue10"
          borderRadius="$10"
          flex={1}
          pressStyle={{ scale: 0.95 }}
          animation="quick"
        >
          <MessageCircle size={20} mr="$2" />
          Message
        </Button>
        <Button 
          size="$4"
          backgroundColor="$color5"
          borderRadius="$10"
          pressStyle={{ scale: 0.95 }}
          animation="quick"
        >
          <Heart size={20} />
        </Button>
        <Button 
          size="$4"
          backgroundColor="$color5"
          borderRadius="$10"
          pressStyle={{ scale: 0.95 }}
          animation="quick"
        >
          <Share2 size={20} />
        </Button>
      </XStack>

      {/* Image Lightbox */}
      <Sheet
        modal
        open={showLightbox}
        onOpenChange={setShowLightbox}
        snapPoints={[100]}
        position={0}
        dismissOnSnapToBottom
      >
        <Sheet.Frame backgroundColor="black">
          <Sheet.Handle />
          <View flex={1} ai="center" jc="center">
            {selectedImage && (
              <Image
                source={{ uri: selectedImage.url }}
                width={screenWidth}
                height={screenWidth}
                resizeMode="contain"
              />
            )}
          </View>
        </Sheet.Frame>
      </Sheet>
    </View>
  );
}