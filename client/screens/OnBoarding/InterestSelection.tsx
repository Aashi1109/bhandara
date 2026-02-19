import { getAllTags, getSubTags } from "@/common/api/tags.action";
import type { ITag } from "@/definitions/types";
import { useDataLoader } from "@/hooks";
import React, { Fragment, useEffect, useRef, useState } from "react";
import { type XStackProps, Text, View, XStack } from "tamagui";
import { ChevronRight } from "@tamagui/lucide-icons";
import { SpinningLoader } from "@/components/ui/Loaders";
import { useToastController } from "@tamagui/toast";

const TagButton = ({
  tag,
  isSelected,
  isExpanded,
  onPress,
  isLoading,
  hasChildren
}: {
  tag: ITag;
  isSelected: boolean;
  isExpanded: boolean;
  onPress: () => void;
  isLoading: boolean;
  hasChildren: boolean;
}) => {
  const borderColor = isExpanded ? "$color02" : isSelected ? "$color7" : "$borderColor";
  const bg = isExpanded ? "$accent8" : !isSelected ? "inherit" : "$accent1";
  const color = isExpanded ? "$color1" : isSelected ? "$color1" : "$color08";

  return (
    <XStack
      gap={"$2"}
      rounded={"$12"}
      px={"$3"}
      py={"$2"}
      items="center"
      borderWidth={1}
      borderColor={borderColor}
      bg={bg}
      cursor={"pointer"}
      onPress={onPress}
      hoverStyle={{ borderColor: "$color7", transition: "border-color 0.2s ease-in-out" }}
      transition="all 0.3s ease-in-out"
    >
      <Text>{tag.icon}</Text>
      <Text
        fontSize={"$2"}
        color={color}
      >
        {tag.name}
      </Text>
      {isLoading ? (
        <SpinningLoader />
      ) : hasChildren && (!isExpanded || !tag.subTags) ? (
        <ChevronRight
          size={16}
          color={color}
        />
      ) : null}
    </XStack>
  );
};

const InterestSelection = ({
  cb,
  maxH,
  preSelectedInterests
}: {
  cb: (tag: ITag[]) => void;
  maxH?: XStackProps["maxH"];
  preSelectedInterests?: ITag[];
}) => {
  const toastController = useToastController();

  const {
    loading,
    data: tags,
    setData: setTags
  } = useDataLoader({
    promiseFunction: _getAllTags
  });

  async function _getAllTags() {
    try {
      const resp = await getAllTags();
      return resp.data;
    } catch (error: any) {
      toastController.show(error?.message || "Failed to fetch tags");
    }
  }
  const [loadingSubTagOf, setLoadingSubTagOf] = useState<string | null>(null);
  const [selectedTags, setSelectedTags] = useState<ITag[]>([]);
  const [expandedTagIds, setExpandedTagIds] = useState<string[]>([]);
  const subTagsLoadedParentIds = useRef<Set<string>>(new Set());

  useEffect(() => {
    if (preSelectedInterests) {
      setSelectedTags(preSelectedInterests);
    }
  }, [preSelectedInterests]);

  const handleTagPress = async (tag: ITag) => {
    if (tag.hasChildren) {
      // Toggle expanded state
      setExpandedTagIds((prev) => (prev.includes(tag.id) ? prev.filter((id) => id !== tag.id) : [...prev, tag.id]));

      // Load subtags if not already loaded
      if (!subTagsLoadedParentIds.current.has(tag.id)) {
        setLoadingSubTagOf(tag.id);
        const { data: subTags, error: subTagsError } = await getSubTags(tag.id);

        if (subTags && !subTagsError) {
          setTags((prev) => (prev || []).map((t) => (t.id === tag.id ? { ...t, subTags } : t)));
          subTagsLoadedParentIds.current.add(tag.id);
        }
        setLoadingSubTagOf(null);
      }
    } else {
      // Handle selection of leaf tags
      const isAlreadySelected = selectedTags.some((t) => t.id === tag.id);
      const newSelectedTags = isAlreadySelected ? selectedTags.filter((t) => t.id !== tag.id) : [...selectedTags, tag];

      setSelectedTags(newSelectedTags);
      setExpandedTagIds((prev) => prev.filter((id) => id !== tag.id));
      cb(newSelectedTags);
    }
  };

  const isTagSelected = (tag: ITag, isExpanded: boolean) => {
    return !!(
      selectedTags.some((t) => t.id === tag.id) ||
      (!isExpanded && tag.subTags?.some((subTag) => selectedTags.some((selectedTag) => selectedTag.id === subTag.id)))
    );
  };

  if (loading) {
    return (
      <View
        height={300}
        width={400}
        justify="center"
        items="center"
      >
        <SpinningLoader />
      </View>
    );
  }

  return (
    <XStack
      flexWrap="wrap"
      gap={"$4"}
      maxH={maxH}
      overflow="scroll"
    >
      {tags?.map((tag) => {
        const isExpanded = expandedTagIds.includes(tag.id);
        const isSelected = isTagSelected(tag, isExpanded);
        const hasChildTagsLoaded = subTagsLoadedParentIds.current.has(tag.id);

        return (
          <Fragment key={tag.id}>
            <TagButton
              tag={tag}
              isSelected={isSelected}
              isExpanded={isExpanded}
              onPress={() => handleTagPress(tag)}
              isLoading={loadingSubTagOf === tag.id}
              hasChildren={!!tag.hasChildren}
            />

            {hasChildTagsLoaded &&
              isExpanded &&
              tag.subTags?.map((subTag) => (
                <TagButton
                  key={subTag.id}
                  tag={subTag}
                  isSelected={selectedTags.some((t) => t.id === subTag.id)}
                  isExpanded={false}
                  onPress={() => handleTagPress(subTag)}
                  isLoading={false}
                  hasChildren={false}
                />
              ))}
          </Fragment>
        );
      })}
    </XStack>
  );
};

export default InterestSelection;
