import "react-day-picker/src/style.css";

import { useState } from "react";
import { Platform } from "react-native";
import { YStack, XStack, Button, Text, styled, useMedia, H4, View, AnimatePresence } from "tamagui";
import DateTimePicker from "@react-native-community/datetimepicker";
import {
  Day,
  DayButton,
  DayPicker,
  MonthCaption,
  NextMonthButton,
  PreviousMonthButton,
  Weekday
} from "react-day-picker";
import { FilledButton, OutlineButton } from "../ui/Buttons";
import { QUICK_RANGES } from "./quickRanges";
import { ChevronLeft, ChevronRight } from "@tamagui/lucide-icons";
import { formatDateWithTimeString } from "@/utils/date.utils";

const SidebarButton = styled(Button, {
  justify: "flex-start",
  rounded: "$4",
  bg: "transparent",
  color: "$color",
  px: "$3",
  py: "$2",
  hoverStyle: { bg: "$black2" },
  pressStyle: { bg: "$black3" },
  transition: "all 0.3s ease-in"
});

const CalendarContainer = styled(XStack, {
  gap: "$4",
  overflow: "hidden"
});

const DateRangeDisplay = ({ from, to }: { from?: Date; to?: Date }) => (
  <XStack gap="$2">
    <Text fontSize={"$3"}>{from ? formatDateWithTimeString(from) : "Start"}</Text>
    <Text fontSize={"$3"}>-</Text>
    <Text fontSize={"$3"}>{to ? formatDateWithTimeString(to) : "End"}</Text>
  </XStack>
);

const StyledDayButton = styled(DayButton, {
  variants: {
    isSelected: {
      true: {
        bg: "$color12",
        borderWidth: 1,
        borderColor: "$color6"
      }
    },
    isInRange: {
      true: {
        bg: "$color6",
        borderWidth: 0,
        rounded: 0,
        borderColor: "transparent"
      }
    },
    isToday: {
      true: {
        borderWidth: 1,
        borderColor: "$color8",
        bg: "$color8"
      }
    },
    isTodayAndInRange: {
      true: {
        background: "$color8",
        rounded: 1000
      }
    }
  } as const
});

const StyledDay = styled(Day, {
  variants: {
    isInRange: {
      true: {
        background: "$color6"
      }
    },
    isStart: {
      true: {
        background: "$color6",
        borderTopLeftRadius: 10000,
        borderBottomLeftRadius: 10000
      }
    },
    isEnd: {
      true: {
        background: "$color6",
        borderTopRightRadius: 10000,
        borderBottomRightRadius: 10000
      }
    },
    isTodayAndInRange: {
      true: {
        background: "$color6"
      }
    }
  } as const
});

function setTimeOnDate(date: Date, time: string) {
  const [h, m] = time.split(":");
  const newDate = new Date(date);
  newDate.setHours(parseInt(h, 10));
  newDate.setMinutes(parseInt(m, 10));
  newDate.setSeconds(0);
  newDate.setMilliseconds(0);
  return newDate;
}

function getTimeFromDate(date: Date): string {
  const hours = date.getHours().toString().padStart(2, "0");
  const minutes = date.getMinutes().toString().padStart(2, "0");
  return `${hours}:${minutes}`;
}

export default function DateRangePicker({
  onClose,
  onSubmit,
  initialDates
}: {
  onClose: () => void;
  onSubmit: (...args: Date[]) => void;
  initialDates?: Date[];
}) {
  const [selectedRange, setSelectedRange] = useState<{ from?: Date; to?: Date }>({
    from: initialDates?.[0],
    to: initialDates?.[1]
  });
  const [showStart, setShowStart] = useState(false);
  const [showEnd, setShowEnd] = useState(false);
  const [startTime, setStartTime] = useState<string>(initialDates?.[0] ? getTimeFromDate(initialDates[0]) : "00:00");
  const [endTime, setEndTime] = useState<string>(initialDates?.[1] ? getTimeFromDate(initialDates[1]) : "00:00");
  const today = new Date();
  const [visibleMonth, setVisibleMonth] = useState(new Date(2025, 0));

  const [sideBarWidth, setSideBarWidth] = useState(0);

  const showSidebar = !!sideBarWidth;

  const handleTimeChange = (key: "from" | "to", value: string) => {
    const [h, m] = value.split(":");
    setSelectedRange((prev) => {
      const date = prev[key] || new Date();
      const newDate = new Date(date);
      newDate.setHours(parseInt(h, 10));
      newDate.setMinutes(parseInt(m, 10));
      return { ...prev, [key]: newDate } as any;
    });
    key === "from" ? setStartTime(value) : setEndTime(value);
  };

  return (
    <CalendarContainer>
      <View
        position="relative"
        transition={"quick"}
        width={showSidebar ? 120 : 0}
      >
        <OutlineButton
          onPress={() => setSideBarWidth((prev) => (!prev ? 120 : 0))}
          size={"small"}
          position="absolute"
          t={0}
          r={showSidebar ? 0 : "unset"}
          p={0}
          rounded={8}
        >
          {showSidebar ? <ChevronLeft /> : <ChevronRight />}
        </OutlineButton>
        {showSidebar && (
          <YStack
            gap="$2"
            mt={"$6"}
            transition={"quick"}
            width={120}
          >
            {QUICK_RANGES.map(({ label, range }) => (
              <SidebarButton
                key={label}
                onPress={() => {
                  setSelectedRange({
                    from: range.from ? setTimeOnDate(range.from, startTime) : undefined,
                    to: range.to ? setTimeOnDate(range.to, endTime) : undefined
                  });
                }}
              >
                {label}
              </SidebarButton>
            ))}
          </YStack>
        )}
      </View>
      <YStack
        gap="$4"
        flex={1}
        justify="space-between"
        mt={"$6"}
      >
        {Platform.OS === "web" ? (
          <XStack
            gap="$4"
            overflowX="scroll"
            justify={"center"}
          >
            <DayPicker
              mode="range"
              animate={true}
              components={{
                MonthCaption: ({ children, ...rest }) => (
                  <MonthCaption {...rest}>
                    <Text
                      fontSize={20}
                      display="flex"
                      justify={"center"}
                    >
                      {children}
                    </Text>
                  </MonthCaption>
                ),
                Weekday: ({ children, ...props }) => {
                  return (
                    <Weekday {...props}>
                      <Text>{children}</Text>
                    </Weekday>
                  );
                },
                Day: ({ children, ...props }) => {
                  const { modifiers } = props;

                  const isInRange = modifiers.range_middle;
                  const isStart = modifiers.range_start;
                  const isEnd = modifiers.range_end;

                  return (
                    <StyledDay
                      {...(props as any)}
                      isInRange={isInRange && !modifiers.today}
                      isStart={isStart}
                      isEnd={isEnd}
                      isTodayAndInRange={modifiers.today && isInRange}
                    >
                      {children}
                    </StyledDay>
                  );
                },
                DayButton: ({ children, ...props }) => {
                  const { modifiers } = props;

                  const isSelected = modifiers.selected || modifiers.range_start || modifiers.range_end;
                  const isInRange = modifiers.range_middle;

                  const isToday = modifiers.today;

                  return (
                    <StyledDayButton
                      {...(props as any)}
                      isSelected={isSelected}
                      isInRange={isInRange}
                      isToday={isToday}
                      isTodayAndInRange={isToday && isInRange}
                    >
                      <Text
                        fontSize={"$4"}
                        color={isSelected && !isInRange && !isToday ? "$color1" : "$color12"}
                      >
                        {children}
                      </Text>
                    </StyledDayButton>
                  );
                },
                PreviousMonthButton: (props) => {
                  return (
                    <PreviousMonthButton {...props}>
                      <ChevronLeft color={"$color12"} />
                    </PreviousMonthButton>
                  );
                },
                NextMonthButton: (props) => {
                  return (
                    <NextMonthButton {...props}>
                      <ChevronRight color={"$color12"} />
                    </NextMonthButton>
                  );
                }
              }}
              selected={{
                from: selectedRange.from,
                to: selectedRange.to
              }}
              disabled={{
                before: today,
                after: new Date(today.getFullYear(), today.getMonth() + 1, today.getDate())
              }}
              onSelect={(range) => setSelectedRange(range || {})}
              month={visibleMonth}
              numberOfMonths={1}
              defaultMonth={new Date(2025, 0)}
              onMonthChange={setVisibleMonth}
              startMonth={today}
            />
          </XStack>
        ) : (
          <YStack gap="$2">
            <Button onPress={() => setShowStart(true)}>
              {selectedRange?.from?.toDateString() || "Pick Start Date"}
            </Button>
            <Button onPress={() => setShowEnd(true)}>{selectedRange?.to?.toDateString() || "Pick End Date"}</Button>
            {showStart && (
              <DateTimePicker
                value={selectedRange?.from || new Date()}
                mode="date"
                display="default"
                onChange={(e, date) => {
                  setShowStart(false);
                  if (date) setSelectedRange((prev) => ({ ...prev, from: date }));
                }}
              />
            )}
            {showEnd && (
              <DateTimePicker
                value={selectedRange?.to || new Date()}
                mode="date"
                display="default"
                onChange={(e, date) => {
                  setShowEnd(false);
                  if (date) setSelectedRange((prev) => ({ ...prev, to: date }));
                }}
              />
            )}
          </YStack>
        )}

        <XStack
          gap="$2"
          mb="$2"
          justify={"center"}
        >
          <input
            type="time"
            value={startTime}
            onChange={(e) => handleTimeChange("from", e.target.value)}
            style={{ padding: "8px 12px", fontFamily: "Inter", borderRadius: 12, border: "none" }}
          />
          <input
            type="time"
            value={endTime}
            onChange={(e) => handleTimeChange("to", e.target.value)}
            style={{ padding: "8px 12px", fontFamily: "Inter", borderRadius: 12, border: "none" }}
          />
        </XStack>

        <YStack
          justify="space-between"
          items="center"
          gap={"$4"}
        >
          <DateRangeDisplay
            from={selectedRange?.from}
            to={selectedRange?.to}
          />
          <XStack
            gap="$2"
            justify={"flex-end"}
            width="100%"
          >
            <OutlineButton
              onPress={() => {
                setSelectedRange({});
                onClose();
              }}
              size={"medium"}
            >
              Cancel
            </OutlineButton>
            <FilledButton
              size={"medium"}
              width={"auto"}
              disabled={!selectedRange.from || !selectedRange.to}
              onPress={() => onSubmit(selectedRange.from!, selectedRange.to!)}
            >
              Apply
            </FilledButton>
          </XStack>
        </YStack>
      </YStack>
    </CalendarContainer>
  );
}
