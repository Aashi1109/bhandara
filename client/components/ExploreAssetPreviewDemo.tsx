import React from "react";
import { YStack, Text, H4 } from "tamagui";
import ExploreAssetPreview from "./ExploreAssetPreview";
import { EMediaType } from "@/definitions/enums";
import { IBaseUser } from "@/definitions/types";

// Sample data for demonstration
const sampleCreator: IBaseUser = {
  id: "1",
  name: "Chef Maria",
  username: "chefmaria",
  email: "maria@example.com",
  profilePic: {
    url: "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face",
    publicUrl: "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face"
  },
  createdAt: new Date().toISOString(),
  updatedAt: new Date().toISOString()
};

const sampleLocation = {
  latitude: 40.7128,
  longitude: -74.0060,
  city: "New York",
  country: "USA",
  address: "123 Food Street"
};

const sampleTags = [
  { id: "1", name: "Italian" },
  { id: "2", name: "Pasta" },
  { id: "3", name: "Homemade" }
];

const ExploreAssetPreviewDemo: React.FC = () => {
  const sampleUserLocation = {
    latitude: 40.7589,
    longitude: -73.9851,
    altitude: 0,
    accuracy: 5,
    altitudeAccuracy: 0,
    heading: 0,
    speed: 0
  };

  return (
    <YStack gap="$6" padding="$4">
      <H4>Explore Asset Preview Demo</H4>
      
      <Text fontSize="$3" color="$color10">
        This demo showcases the Instagram-like full-size preview functionality for the explore section.
      </Text>

      {/* Image Preview Example */}
      <YStack gap="$3">
        <Text fontSize="$4" fontWeight="600">Image Preview</Text>
        <ExploreAssetPreview
          media={{
            type: EMediaType.Image,
            url: "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=800&h=600&fit=crop",
            thumbnailUrl: "https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400&h=300&fit=crop"
          }}
          title="Delicious Homemade Pizza"
          location={sampleLocation}
          creator={sampleCreator}
          createdAt={new Date().toISOString()}
          likes={42}
          comments={8}
          userLocation={sampleUserLocation}
          tags={sampleTags}
          showPreviewButton={true}
          previewButtonText="View Recipe"
        />
      </YStack>

      {/* Video Preview Example */}
      <YStack gap="$3">
        <Text fontSize="$4" fontWeight="600">Video Preview</Text>
        <ExploreAssetPreview
          media={{
            type: EMediaType.Video,
            url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
            thumbnailUrl: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg"
          }}
          title="Cooking Tutorial: Perfect Pasta"
          location={sampleLocation}
          creator={sampleCreator}
          createdAt={new Date().toISOString()}
          likes={156}
          comments={23}
          userLocation={sampleUserLocation}
          tags={sampleTags}
          showPreviewButton={true}
          previewButtonText="Watch Tutorial"
        />
      </YStack>

      {/* Event Preview Example */}
      <YStack gap="$3">
        <Text fontSize="$4" fontWeight="600">Event Preview</Text>
        <ExploreAssetPreview
          media={{
            type: EMediaType.Image,
            url: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&h=600&fit=crop",
            thumbnailUrl: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop"
          }}
          title="Italian Cooking Workshop"
          location={sampleLocation}
          creator={sampleCreator}
          createdAt={new Date().toISOString()}
          startTime={new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()}
          endTime={new Date(Date.now() + 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000).toISOString()}
          going={15}
          userLocation={sampleUserLocation}
          tags={sampleTags}
          showPreviewButton={true}
          previewButtonText="Join Event"
        />
      </YStack>

      <Text fontSize="$2" color="$color10" textAlign="center">
        Click on any preview to see the full-size modal with zoom capabilities!
      </Text>
    </YStack>
  );
};

export default ExploreAssetPreviewDemo;