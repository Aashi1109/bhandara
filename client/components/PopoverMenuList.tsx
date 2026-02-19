import React, { Fragment, memo } from "react";
import { PopoverContent } from "./ui/common-styles";
import { Popover, Separator, Text, XStack, YStack } from "tamagui";
import { kebabCase } from "@/utils";
import type { GestureResponderEvent } from "react-native";

interface IPopoverMenuList {
  groups: {
    label: string;
    tabs: {
      label: string;
      icon: React.ReactElement;
      color?: string;
    }[];
  }[];
  handleActionClick: (action: string, e?: GestureResponderEvent) => void;
}

const PopoverMenuList = ({ groups, handleActionClick }: IPopoverMenuList) => {
  return (
    <PopoverContent
      mr="$4"
      p={"$3"}
      rounded={"$4"}
    >
      <YStack gap="$3">
        {groups.map((group, index) => (
          <Fragment key={group.label + index}>
            <YStack
              key={group.label}
              gap={"$3"}
            >
              {group.tabs.map((tab) => (
                <Popover.Close key={tab.label} asChild>
                  <XStack
                    gap={"$3"}
                    items={"center"}
                    cursor={"pointer"}
                    onPress={(e) => handleActionClick(kebabCase(tab.label), e)}
                  >
                    {React.cloneElement(tab.icon, {
                      size: 16,
                      color: (tab as any)?.color
                    })}
                    <Text
                      fontSize={"$3"}
                      color={(tab as any)?.color}
                    >
                      {tab.label}
                    </Text>
                  </XStack>
                </Popover.Close>
              ))}
            </YStack>
            {index !== groups.length - 1 && <Separator />}
          </Fragment>
        ))}
      </YStack>
    </PopoverContent>
  );
};

export default memo(PopoverMenuList);
