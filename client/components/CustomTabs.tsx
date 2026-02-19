import { ScrollView, SizableText, XStack , Tabs } from "tamagui";

import { kebabCase } from "@/utils";
import React from "react";

interface IProps {
  tabs: {
    label: string;
    icon?: React.ReactElement;
    content: React.ReactNode;
  }[];
  defaultValue: string;
  cb?: (value: string) => void;
  orientation?: "horizontal" | "vertical";
}

const HorizontalTabs = ({ tabs, defaultValue, cb, orientation = "horizontal" }: IProps) => {
  return (
    <Tabs
      defaultValue={defaultValue}
      orientation={orientation}
      flexDirection={orientation !== "horizontal" ? "row" : "column"}
      flex={1}
      gap={"$5"}
    >
      <Tabs.List
        disablePassBorderRadius="bottom"
        aria-label="Manage your account"
        rounded={"$4"}
        $gtMd={{ maxW: 500 }}
        width={350}
        maxW={350}
        borderWidth={"$0.25"}
        borderColor="$borderColor"
        overflow="hidden"
        self={"center"}
      >
        {tabs.map((tab) => {
          const _uniqueKey = kebabCase(tab.label);
          return (
            <Tabs.Tab
              focusStyle={{
                backgroundColor: "$color3"
              }}
              flex={1}
              width={"100%"}
              height={"$3"}
              value={_uniqueKey}
              onPress={() => {
                cb?.(_uniqueKey);
              }}
              key={_uniqueKey}
            >
              <XStack
                gap={"$2"}
                items={"center"}
              >
                {tab.icon &&
                  React.cloneElement(tab.icon, {
                    size: 16
                  })}
                <SizableText
                  fontFamily="$body"
                  text="center"
                >
                  {tab.label}
                </SizableText>
              </XStack>
            </Tabs.Tab>
          );
        })}
      </Tabs.List>

      {tabs.map((tab) => {
        return (
          <Tabs.Content
            flex={1}
            value={kebabCase(tab.label)}
            items={"stretch"}
            key={kebabCase(tab.label)}
          >
            <ScrollView
              flex={1}
              width={"100%"}
              height={"100%"}
            >
              {tab.content}
            </ScrollView>
          </Tabs.Content>
        );
      })}
    </Tabs>
  );
};

export default HorizontalTabs;
