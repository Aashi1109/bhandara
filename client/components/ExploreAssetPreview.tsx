import React, { useState, useCallback, useMemo } from "react";
import { useDialog } from "@/hooks/useModal";
import { AssetPreviewDialog } from "@/screens/EventDetails/AssetPreviewDialog";
import { IMedia, IBaseUser } from "@/definitions/types";
import { EMediaType } from "@/definitions/enums";
import { Image, View, Text, XStack, YStack } from "tamagui";
import { Heart, MessageCircle, MapPin, Clock, Users } from "@tamagui/lucide-icons";
import { formatDistance } from "@/helpers";
import { haversineDistanceInM } from "@/utils/location";
import { LocationObjectCoords } from "expo-location";
import { formatDateWithTimeString } from "@/utils/date.utils";
import OptimizedMediaLoader from "./OptimizedMediaLoader";

interface ExploreAssetPreviewProps {
  media: {
    type: string;
    url: string;
    thumbnailUrl: string;
  };
  title: string;
  location: any;
  creator: IBaseUser;
  createdAt: string;
  startTime?: string;
  endTime?: string;
  likes?: number;
  comments?: number;
  going?: number;
  userLocation?: LocationObjectCoords | null;
  tags?: any[];
  onPress?: () => void;
  showPreviewButton?: boolean;
  previewButtonText?: string;
}

const ExploreAssetPreview: React.FC<ExploreAssetPreviewProps> = ({
  media,
  title,
  location,
  creator,
  createdAt,
  startTime,
  endTime,
  likes = 0,
  comments = 0,
  going = 0,
  userLocation,
  tags = [],
  onPress,
  showPreviewButton = true,
  previewButtonText = "Preview"
}) => {
  const { open, close, RenderContent } = useDialog();
  
  // Convert the media object to IMedia format for AssetPreviewDialog
  const mediaForPreview: IMedia = useMemo(() => ({
    id: `preview-${Date.now()}`,
    type: media.type as EMediaType,
    publicUrl: media.url,
    thumbnailUrl: media.thumbnailUrl,
    name: title,
    createdAt,
    updatedAt: createdAt,
    size: 0,
    mimeType: media.type === EMediaType.Image ? 'image/jpeg' : 'video/mp4'
  }), [media, title, createdAt]);

  const handlePreviewPress = useCallback(() => {
    open();
  }, [open]);

  const handleCardPress = useCallback(() => {
    if (onPress) {
      onPress();
    } else {
      handlePreviewPress();
    }
  }, [onPress, handlePreviewPress]);

  // Calculate distance if user location is available
  const distanceAway = useMemo(() => {
    if (!userLocation || !location?.latitude || !location?.longitude) return null;
    
    return haversineDistanceInM(
      { latitude: userLocation.latitude, longitude: userLocation.longitude },
      { latitude: location.latitude, longitude: location.longitude }
    );
  }, [userLocation, location]);

  const distanceLabel = distanceAway ? formatDistance(distanceAway) : null;

  // Format time range
  const timeRange = useMemo(() => {
    if (!startTime || !endTime) return null;
    
    const start = new Date(startTime).toLocaleTimeString([], { 
      hour: "2-digit", 
      minute: "2-digit" 
    });
    const end = new Date(endTime).toLocaleTimeString([], { 
      hour: "2-digit", 
      minute: "2-digit" 
    });
    
    return `${start} - ${end}`;
  }, [startTime, endTime]);

  return (
    <>
      <View
        position="relative"
        cursor="pointer"
        onPress={handleCardPress}
        group
      >
        {/* Media Container */}
        <View
          position="relative"
          overflow="hidden"
          borderRadius="$4"
        >
          <OptimizedMediaLoader
            uri={media.url}
            thumbnailUri={media.thumbnailUrl}
            type={media.type as EMediaType}
            width="100%"
            height={280}
            objectFit="cover"
            borderRadius="$4"
            showPlayButton={media.type === EMediaType.Video}
            onPress={handlePreviewPress}
          />
          
          {/* Overlay with info */}
          <YStack
            position="absolute"
            bottom={0}
            left={0}
            right={0}
            padding="$3"
            background="linear-gradient(transparent, rgba(0,0,0,0.7))"
            opacity={0}
            $group-hover={{ opacity: 1 }}
            animation="quick"
          >
            <Text
              color="white"
              fontSize="$4"
              fontWeight="600"
              numberOfLines={2}
              marginBottom="$2"
            >
              {title}
            </Text>
            
            <XStack gap="$3" alignItems="center" marginBottom="$2">
              <XStack gap="$1" alignItems="center">
                <MapPin size={14} color="white" />
                <Text color="white" fontSize="$2">
                  {location?.city} {location?.country}
                </Text>
              </XStack>
              
              {distanceLabel && (
                <Text color="white" fontSize="$2">
                  {distanceLabel} away
                </Text>
              )}
            </XStack>
            
            {timeRange && (
              <XStack gap="$1" alignItems="center" marginBottom="$2">
                <Clock size={14} color="white" />
                <Text color="white" fontSize="$2">
                  {timeRange}
                </Text>
              </XStack>
            )}
            
            <XStack gap="$4" alignItems="center">
              {likes > 0 && (
                <XStack gap="$1" alignItems="center">
                  <Heart size={14} color="white" />
                  <Text color="white" fontSize="$2">{likes}</Text>
                </XStack>
              )}
              
              {comments > 0 && (
                <XStack gap="$1" alignItems="center">
                  <MessageCircle size={14} color="white" />
                  <Text color="white" fontSize="$2">{comments}</Text>
                </XStack>
              )}
              
              {going > 0 && (
                <XStack gap="$1" alignItems="center">
                  <Users size={14} color="white" />
                  <Text color="white" fontSize="$2">{going} going</Text>
                </XStack>
              )}
            </XStack>
          </YStack>
          
          {/* Preview button overlay */}
          {showPreviewButton && (
            <View
              position="absolute"
              top="$3"
              right="$3"
              backgroundColor="rgba(0,0,0,0.6)"
              paddingHorizontal="$3"
              paddingVertical="$2"
              borderRadius="$2"
              opacity={0}
              $group-hover={{ opacity: 1 }}
              animation="quick"
            >
              <Text color="white" fontSize="$2" fontWeight="500">
                {previewButtonText}
              </Text>
            </View>
          )}
        </View>
        
        {/* Creator info below media */}
        <YStack padding="$3" gap="$2">
          <XStack gap="$2" alignItems="center">
            <Image
              source={{ uri: creator?.profilePic?.url || "" }}
              width={32}
              height={32}
              borderRadius="$6"
              objectFit="cover"
            />
            <YStack flex={1}>
              <Text fontSize="$3" fontWeight="500">
                {creator?.name}
              </Text>
              <Text fontSize="$2" color="$color10">
                {creator?.username}
              </Text>
            </YStack>
          </XStack>
          
          {/* Tags */}
          {tags.length > 0 && (
            <XStack gap="$1" flexWrap="wrap">
              {tags.slice(0, 3).map((tag, index) => (
                <View
                  key={index}
                  backgroundColor="$color5"
                  paddingHorizontal="$2"
                  paddingVertical="$1"
                  borderRadius="$2"
                >
                  <Text fontSize="$1" color="$color11">
                    #{tag.name}
                  </Text>
                </View>
              ))}
              {tags.length > 3 && (
                <Text fontSize="$1" color="$color10">
                  +{tags.length - 3} more
                </Text>
              )}
            </XStack>
          )}
        </YStack>
      </View>

      {/* Full-size preview modal */}
      <RenderContent>
        <AssetPreviewDialog
          medias={[mediaForPreview]}
          currentSelectedMediaId={mediaForPreview.id}
          close={close}
        />
      </RenderContent>
    </>
  );
};

export default ExploreAssetPreview;