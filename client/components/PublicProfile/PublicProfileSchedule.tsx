import React, { useState } from "react";
import { View, Text, XStack, YStack, Card, H3, ScrollView, Button } from "tamagui";
import { MapPin, Clock } from "@tamagui/lucide-icons";

interface Activity {
  type: string;
  icon: string;
  time: string;
  location: string;
}

interface ScheduleDay {
  id: string;
  day: string;
  activities: Activity[];
}

interface PublicProfileScheduleProps {
  schedule: ScheduleDay[];
}

export default function PublicProfileSchedule({ schedule }: PublicProfileScheduleProps) {
  const [selectedDay, setSelectedDay] = useState(schedule[0]?.id);

  const selectedDayData = schedule.find(day => day.id === selectedDay);

  return (
    <YStack space="$4">
      {/* Day Selector */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <XStack space="$2" px="$4">
          {schedule.map((day) => {
            const isSelected = day.id === selectedDay;
            const hasActivities = day.activities.length > 0;
            
            return (
              <Button
                key={day.id}
                size="$5"
                onPress={() => setSelectedDay(day.id)}
                backgroundColor={isSelected ? "$color12" : "$color4"}
                borderRadius="$4"
                borderWidth={0}
                pressStyle={{ scale: 0.95 }}
                animation="quick"
                minWidth="$8"
              >
                <YStack alignItems="center" space="$1">
                  <Text 
                    fontSize="$5" 
                    fontWeight={isSelected ? "700" : "500"}
                    color={isSelected ? "$color1" : "$color11"}
                  >
                    {day.day}
                  </Text>
                  {hasActivities && (
                    <View
                      width={6}
                      height={6}
                      borderRadius="$10"
                      backgroundColor={isSelected ? "$color1" : "$blue10"}
                    />
                  )}
                </YStack>
              </Button>
            );
          })}
        </XStack>
      </ScrollView>

      {/* Activities */}
      <YStack space="$3" minHeight={200}>
        {selectedDayData?.activities.length === 0 ? (
          <View flex={1} alignItems="center" justifyContent="center">
            <Text color="$color11" fontSize="$4">No activities scheduled</Text>
          </View>
        ) : (
          selectedDayData?.activities.map((activity, index) => (
            <Card
              key={index}
              elevate
              bordered
              padding="$4"
              backgroundColor="$color2"
              pressStyle={{ scale: 0.98 }}
              animation="quick"
            >
              <XStack space="$3" alignItems="center">
                {/* Activity Icon */}
                <View
                  width="$5"
                  height="$5"
                  borderRadius="$10"
                  backgroundColor="$color4"
                  alignItems="center"
                  justifyContent="center"
                >
                  <Text fontSize="$6">{activity.icon}</Text>
                </View>

                {/* Activity Details */}
                <YStack flex={1} space="$1">
                  <Text fontSize="$4" fontWeight="600" color="$color12">
                    {activity.type}
                  </Text>
                  
                  <XStack space="$3">
                    <XStack space="$1" alignItems="center">
                      <Clock size={14} color="$color11" />
                      <Text fontSize="$2" color="$color11">
                        {activity.time}
                      </Text>
                    </XStack>
                    
                    <XStack space="$1" alignItems="center">
                      <MapPin size={14} color="$color11" />
                      <Text fontSize="$2" color="$color11">
                        {activity.location}
                      </Text>
                    </XStack>
                  </XStack>
                </YStack>
              </XStack>
            </Card>
          ))
        )}
      </YStack>
    </YStack>
  );
}