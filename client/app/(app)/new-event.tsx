import {
  InputGroup,
  InputGroupWrapper,
  InputLabelWrapper,
  InputLabel,
  InputLabelRightText,
  InputField,
  InputErrorText
} from "@/components/Form";
import { IAddress, ITag } from "@/definitions/types";
import { Camera, CloudUpload, Image as ImageIcon, Minus, Plus, RotateCw, X } from "@tamagui/lucide-icons";
import React, { useEffect, useRef, useState } from "react";
import { Control, Controller, useForm } from "react-hook-form";
import { Label, ScrollView, Separator, SizeTokens, Switch, View, XStack, YStack } from "tamagui";

import { FilledButton, OutlineButton } from "@/components/ui/Buttons";
import DateRangePicker from "@/components/DatePicker";
import { BackButtonHeader, TagListing } from "@/components/ui/common-components";
import { useDialog } from "@/hooks/useModal";
import LocationInput from "@/components/LocationInput";
import { formatDateWithTimeString } from "@/utils/date.utils";
import { IAttachedFile, processPickedFiles } from "@/common/utils/file.utils";
import { CircularProgressLoader, SpinningLoader } from "@/components/ui/Loaders";
import AssetPreview from "@/components/MessageInputBar/AssetPreview";
import { deleteMedia, IPickerAsset } from "@/common/api/media.action";
import { CardWrapper, CircleBgWrapper } from "@/components/ui/common-styles";
import { Text } from "tamagui";
import * as DocumentPicker from "expo-document-picker";
import { useToastController } from "@tamagui/toast";
import { getUUIDv7 } from "@/helpers";
import { GestureResponderEvent } from "react-native";
import * as ImagePicker from "expo-image-picker";
import { EEventStatus, EEventType, EMediaType } from "@/definitions/enums";
import { isEmpty, startCase } from "@/utils";
import AssetPreviewDialog from "@/screens/EventDetails/AssetPreviewDialog";
import { useAuth } from "@/contexts/AuthContext";
import InterestsDialog from "@/components/InterestsDialog";
import { createEvent, disassociateMediaFromEvent, getEventById, updateEvent } from "@/common/api/events.action";
import { EVENT_MEDIA_BUCKET } from "@/constants/global";
import { useLocalSearchParams, useRouter } from "expo-router";
import { getNavState } from "@/lib/navigationStore";
import { useDataLoader } from "@/hooks";
import { Badge } from "@/components/ui/Badge";

interface IFormData {
  name: string;
  description: string;
  schedule: string;
  location: IAddress;
  images: string[];
  _location?: string;
  capacity: boolean;
  num_capacity: number;
  tags: boolean;
}

const MAX_ATTACHMENT_LIMIT = 10;
const MAX_EVENT_CAPACITY = 9999;
const MIN_EVENT_CAPACITY = 50;

export function SwitchWithLabel(props: {
  size: SizeTokens;
  defaultChecked?: boolean;
  label: string;
  control: Control<any>;
  name: string;
}) {
  const id = `switch-${props.name}`;

  return (
    <Controller
      name={props.name}
      control={props.control}
      render={({ field: { onChange, value } }) => (
        <XStack
          items="center"
          gap="$4"
        >
          <Label
            pr="$0"
            justify="flex-end"
            size={props.size}
            htmlFor={id}
          >
            {props.label}
          </Label>
          <Separator
            minH={20}
            vertical
          />
          <Switch
            id={id}
            size={props.size}
            defaultChecked={props.defaultChecked}
            onCheckedChange={onChange}
            checked={value}
          >
            <Switch.Thumb animation="quicker" />
          </Switch>
        </XStack>
      )}
    ></Controller>
  );
}

const NewEvent = () => {
  const selectedScheduleRef = useRef<Date[] | undefined>();
  const { open: openDateSelection, close: closeDateSelection, RenderContent: RenderDateSelectionContent } = useDialog();
  const { open: openMediaPreview, close: closeMediaPreview, RenderContent: RenderMediaPreviewContent } = useDialog();
  const { open: openInterestsDialog, close: closeInterestsDialog, RenderContent: RenderInterestsDialog } = useDialog();

  const [attachedFiles, setAttachedFiles] = useState<IAttachedFile[]>([]);
  const [selectedTags, setSelectedTags] = useState<ITag[]>([]);
  const toastController = useToastController();

  const tEventId = useRef(getUUIDv7());
  const { user } = useAuth();
  const currentSelectedMediaRef = useRef<string | undefined>();
  const params = useLocalSearchParams();
  const router = useRouter();
  const { loading: isEventLoading, data } = useDataLoader({
    promiseFunction: handleFetchEvent,
    enabled: !!params.id
  });

  const {
    control,
    setValue,
    formState: { errors },
    clearErrors,
    setError,
    handleSubmit,
    watch
  } = useForm<IFormData>({ defaultValues: { num_capacity: 50 } });

  const allValues = watch();
  async function handleFetchEvent() {
    const { data, error } = await getEventById(params.id as string);
    if (error) throw error;
    if (data) {
      setValue("name", data.name);
      setValue("description", data.description);
      setValue("location", data.location);
      setValue("_location", data.location.address);
      setValue(
        "schedule",
        `${formatDateWithTimeString(data.timings.start)} - ${formatDateWithTimeString(data.timings.end)}`
      );
      setValue("capacity", !!data.capacity);
      setValue("num_capacity", data.capacity);
      setSelectedTags(data.tags);
      setAttachedFiles(
        data.media.map((m) => ({
          publicURL: m.publicUrl,
          uploadResult: m,
          name: m.name,
          mimeType: m.mimeType || "",
          size: m.size || 0,
          type: m.type
        }))
      );
      tEventId.current = data.id;
    }
    return data;
  }

  useEffect(() => {
    return () => {
      // delete all the attached files when user has exited but not sent the message
      if (attachedFiles.length) {
        new Promise(async (resolve, reject) => {
          await Promise.all(
            attachedFiles.map((f) => {
              if (f?.uploadResult?.id) {
                return deleteMedia(f.uploadResult.id);
              } else {
                return Promise.resolve(true);
              }
            })
          );
          setAttachedFiles([]);
          resolve("done");
        });
      }
    };
  }, []);

  useEffect(() => {
    if (params.dataKey) {
      const location = getNavState(params.dataKey as string);
      if (!isEmpty(location)) {
        setValue("location", location);
        setValue("_location", location.address);
      }
    }
  }, [params.dataKey]);

  const removeAttachedFile = async (index: number) => {
    try {
      const uploadResult = attachedFiles[index].uploadResult;
      if (uploadResult) {
        attachedFiles[index].isDeleting = true;
        setAttachedFiles(attachedFiles);
        const _params = [params.id as string, uploadResult?.id] as const;
        const handler = params.id ? disassociateMediaFromEvent : deleteMedia;
        await handler(..._params);
      }
      setAttachedFiles((prev) => prev.filter((_, i) => i !== index));
    } catch (error) {
      console.error("Error deleting file", error);
      attachedFiles[index].isDeleting = false;
      setAttachedFiles(attachedFiles);
    }
  };

  const pickImageHandler = async (): Promise<IPickerAsset[]> => {
    const res = await ImagePicker.launchImageLibraryAsync({
      allowsEditing: true,
      quality: MAX_ATTACHMENT_LIMIT,
      allowsMultipleSelection: true
    });
    if (res.canceled) return [] as IPickerAsset[];
    else {
      return res.assets.map((f) => ({
        name: f.fileName || "",
        size: f.fileSize || 0,
        uri: f.uri || "",
        mimeType: f.mimeType || "",
        type: f.type! as EMediaType.Image
      }));
    }
  };

  const pickDocumentsHandler = async () => {
    const res = await DocumentPicker.getDocumentAsync({
      type: ["image/*", "video/*"],
      multiple: true
    });

    if (res.canceled) return [] as IPickerAsset[];
    else {
      return res.assets.map((f) => ({
        name: f.name || "",
        size: f.size || 0,
        uri: f.uri || "",
        mimeType: f.mimeType || "",
        type: f.mimeType?.split("/")?.[0] as EMediaType.Image
      }));
    }
  };

  const handleMediaButtonClick = async (e: GestureResponderEvent, type: "image" | "document") => {
    e.stopPropagation();
    e.preventDefault();

    const handlers = {
      image: pickImageHandler,
      document: pickDocumentsHandler
    };
    let files = await handlers[type]();

    if (isEmpty(files)) return;

    try {
      if (MAX_ATTACHMENT_LIMIT) {
        const currentAssetsCount = +attachedFiles.filter((f) => !f.error).length;

        files = files.slice(0, Math.max(files.length, MAX_ATTACHMENT_LIMIT) - currentAssetsCount);
        if (files.length + currentAssetsCount > MAX_ATTACHMENT_LIMIT) {
          toastController.show(
            `You can only upload ${MAX_ATTACHMENT_LIMIT} ${files.length === 1 ? "file" : "files"} at a time`
          );
        }
      }

      files = files
        .filter((f) => f.size) // keep only files with size
        .filter((f, idx, arr) => arr.findIndex((_f) => _f.name === f.name) === idx); // remove duplicates by name

      const { successCount, errorCount } = await processPickedFiles({
        files,
        opts: { pPath: tEventId.current, bucket: EVENT_MEDIA_BUCKET },
        setAttachedFiles
      });

      if (successCount > 0) {
        toastController.show(`Uploaded ${successCount} ${successCount === 1 ? "file" : "files"} successfully`);
      }
      if (errorCount > 0) {
        toastController.show(`${errorCount} ${errorCount === 1 ? "file" : "files"} failed to upload. You can retry uploading them.`);
      }
    } catch (error: any) {
      toastController.show(error?.message || "Something went wrong");
    }
  };

  const previewableMedias = attachedFiles
    .filter((f) => !isEmpty(f.uploadResult))
    .map((f) => ({
      ...f.uploadResult!,
      user
    }));

  const validateAndFormEventData = (validatedData: IFormData) => {
    if (!selectedTags.length) {
      return setError("tags", { message: "Please add tag(s)." });
    }
    const startTime = selectedScheduleRef.current?.[0];
    let eventStatus = EEventStatus.Cancelled;
    const today = new Date();

    if (new Date(startTime!) > today) eventStatus = EEventStatus.Upcoming;
    if (new Date(startTime!) < today) eventStatus = EEventStatus.Ongoing;

    const payload = {
      location: {
        ...validatedData.location,
        address: validatedData._location
      },
      capacity: validatedData.capacity ? validatedData.num_capacity : undefined,
      createdBy: user?.id,
      media: previewableMedias.map((i) => i.id),
      tags: selectedTags.map((i) => i.id),
      name: validatedData.name,
      description: validatedData.description,
      timings: { start: selectedScheduleRef.current?.[0], end: selectedScheduleRef.current?.[1] },
      type: EEventType.Custom,
      status: eventStatus
    };

    return payload;
  };

  const handleEventCreate = async (validatedData: IFormData) => {
    try {
      const payload = validateAndFormEventData(validatedData);
      const { data, error } = await createEvent({ ...payload, id: tEventId.current });

      if (error) throw error;
      if (data?.id) router.push(`/event/${data?.id}`);
      else router.navigate("/home");
    } catch (error: any) {
      toastController.show(error?.message || "Unable to create event");
    }
  };

  const handleEventUpdate = async (validatedData: IFormData) => {
    try {
      const payload = validateAndFormEventData(validatedData);
      const { data, error } = await updateEvent(params.id as string, { ...payload });
      if (error) throw error;
      if (data?.id) router.push(`/event/${data?.id}`);
      else router.navigate("/home");
    } catch (error: any) {
      toastController.show(error?.message || "Unable to update event");
    }
  };

  if (isEventLoading) return <SpinningLoader />;
  const eventBadgeMapping = {
    [EEventStatus.Cancelled]: { "outline-danger": true },
    [EEventStatus.Ongoing]: { "outline-success": true },
    [EEventStatus.Upcoming]: { "outline-warning": true }
  };

  return (
    <>
      <YStack
        p={"$4"}
        gap={"$4"}
        flex={1}
      >
        <BackButtonHeader
          title={data?.name || "Create New Event"}
          navigateTo="/home"
        >
          {data?.id && (
            <Badge
              {...eventBadgeMapping[data?.status]}
              my={"auto"}
            >
              <Badge.Text>{startCase(data.status)}</Badge.Text>
            </Badge>
          )}
        </BackButtonHeader>
        <YStack
          gap={"$4"}
          px={"$0.5"}
          flex={1}
          overflow="scroll"
        >
          <InputGroup
            control={control}
            name={"name"}
            label={"Event Name"}
            placeHolder={"Enter event name"}
            rules={{
              required: "Event name is required"
            }}
            error={errors.name?.message}
          />
          <InputGroup
            control={control}
            name={"description"}
            label={"Description"}
            placeHolder={"Describe your event in short words"}
            error={errors.description?.message}
            inputProps={{ multiline: true, numberOfLines: 4 }}
          />

          <LocationInput
            control={control}
            errors={{ _location: errors._location }}
            setValue={(value) => {
              const { _location, ...rest } = value;
              setValue("location", {
                ...rest
              });
              setValue("_location", _location);
              clearErrors("_location");
            }}
            existingLocation={{ ...allValues.location, _location: allValues._location }}
            isViewOnly={false}
          />

          <InputGroup
            control={control}
            name={"schedule"}
            label={"Schedule"}
            placeHolder={"Enter event schedule"}
            rules={{
              required: "Schedule is required"
            }}
            inputProps={{ editable: false, onPress: openDateSelection }}
            error={errors.schedule?.message}
          />

          <InputGroupWrapper>
            <InputLabelWrapper>
              <InputLabel>Medias</InputLabel>
              {!!attachedFiles.length && <InputLabelRightText>{attachedFiles.length} File(s)</InputLabelRightText>}
            </InputLabelWrapper>
            <YStack gap={"$3"}>
              {attachedFiles.length > 0 && (
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  mt={"$-1"}
                >
                  <XStack gap={"$2"}>
                    {attachedFiles.map((file, index) => {
                      const isUploading = file.uploadedRatio && file.uploadedRatio !== 100;
                      const hasError = file.error;
                      const showPreview = !isUploading && !hasError && (file.uri || file.publicURL);
                      const fileMediaId = file.uploadResult?.id;

                      return (
                        <XStack
                          key={`${file.name}-${index}`}
                          position="relative"
                          group
                          cursor="pointer"
                          height={50}
                          width={50}
                          onPress={() => {
                            if (showPreview) {
                              currentSelectedMediaRef.current = fileMediaId;
                              openMediaPreview();
                            }
                          }}
                        >
                          {(isUploading || hasError) && (
                            <View
                              t={0}
                              l={0}
                              position="absolute"
                              height={50}
                              width={50}
                              items={"center"}
                              justify={"center"}
                              rounded={"$3"}
                              bg={file.error ? "$red1" : "rgba(0, 0, 0, 0.3)"}
                              borderColor={file.error ? "$red10" : "transparent"}
                              borderWidth={file.error ? "$0.25" : 0}
                              overflow="hidden"
                            >
                              {file.error ? (
                                <RotateCw
                                  size={20}
                                  cursor="pointer"
                                  onPress={file.retryCallback}
                                />
                              ) : (
                                <CircularProgressLoader
                                  size={24}
                                  progress={file.uploadedRatio || 0}
                                />
                              )}
                            </View>
                          )}
                          {showPreview && (
                            <AssetPreview
                              type={file.type}
                              file={file.uri}
                              publicLink={file.publicURL}
                            />
                          )}

                          <OutlineButton
                            icon={file.isDeleting ? <SpinningLoader /> : <X size={12} />}
                            height={18}
                            p={"$1"}
                            width={18}
                            t={2}
                            r={2}
                            position="absolute"
                            disabled={file.isDeleting}
                            display={file.isDeleting ? "flex" : "none"}
                            onPress={(e) => {
                              e.stopPropagation();
                              e.preventDefault();
                              removeAttachedFile(index);
                            }}
                            $group-hover={{
                              display: "flex"
                            }}
                          />

                          {/* {hasError && (
                            <Badge
                              outline-danger
                              rounded={1000}
                              group
                              width={20}
                            >
                              <XStack
                                gap={"$1.5"}
                                items={"center"}
                              >
                                <HelpCircle
                                  color={"$red9"}
                                  size={14}
                                />
                                <Text
                                  fontSize={"$2"}
                                  color={"$red9"}
                                  display="none"
                                  $group-hover={{ display: "flex" }}
                                >
                                  {file.error}
                                </Text>
                              </XStack>
                            </Badge>
                          )} */}
                        </XStack>
                      );
                    })}
                  </XStack>
                </ScrollView>
              )}
              <CardWrapper
                items={"center"}
                justify={"center"}
                cursor="pointer"
              >
                <YStack
                  gap={"$3"}
                  items={"center"}
                >
                  <CircleBgWrapper
                    bg={"$color6"}
                    p={"$4"}
                  >
                    <CloudUpload size={28} />
                  </CircleBgWrapper>
                  <YStack
                    gap={"$2"}
                    items={"center"}
                  >
                    <Text>Upload your file(s)</Text>
                    <Text
                      fontSize={"$3"}
                      color={"$color11"}
                    >
                      PNG, JPEG, MP4, MOV upto 10MB
                    </Text>
                  </YStack>

                  <XStack
                    gap={"$4"}
                    items={"center"}
                  >
                    <OutlineButton
                      rounded={"$2"}
                      icon={<Camera />}
                      onPress={(e) => handleMediaButtonClick(e, "image")}
                    >
                      <Text>Camera</Text>
                    </OutlineButton>
                    <OutlineButton
                      rounded={"$2"}
                      icon={<ImageIcon />}
                      onPress={(e) => handleMediaButtonClick(e, "document")}
                    >
                      <Text>Gallery</Text>
                    </OutlineButton>
                  </XStack>
                </YStack>
              </CardWrapper>
            </YStack>
          </InputGroupWrapper>

          <InputGroupWrapper>
            <XStack
              justify={"space-between"}
              items={"center"}
              gap={"$4"}
            >
              <InputLabel>Tags</InputLabel>
              <Plus
                size={"$1"}
                cursor="pointer"
                onPress={openInterestsDialog}
              />
            </XStack>
            {!!selectedTags.length && <TagListing tags={selectedTags} />}
            {errors?.tags && <InputErrorText>{errors.tags?.message}</InputErrorText>}
          </InputGroupWrapper>

          <XStack
            justify={"space-between"}
            items={"center"}
            mt={"$2"}
          >
            <SwitchWithLabel
              control={control}
              size={"$3"}
              label="Capacity"
              name="capacity"
            />

            <InputGroupWrapper flex={0}>
              <XStack
                gap={"$1"}
                items={"center"}
                display={allValues.capacity ? "flex" : "none"}
              >
                <OutlineButton
                  icon={<Minus />}
                  p={"$2"}
                  onPress={() => setValue("num_capacity", +allValues.num_capacity - 10)}
                  disabled={allValues.num_capacity <= MIN_EVENT_CAPACITY}
                />
                <Controller
                  name="num_capacity"
                  control={control}
                  rules={{
                    min: { value: MIN_EVENT_CAPACITY, message: `Min ${MIN_EVENT_CAPACITY}` },
                    max: { value: MAX_EVENT_CAPACITY, message: `Min ${MAX_EVENT_CAPACITY}` }
                  }}
                  render={({ field }) => (
                    <InputField
                      height={28}
                      maxW={35}
                      text={"center"}
                      keyboardType="numeric"
                      value={field.value?.toString()}
                      onChange={(e) => {
                        // @ts-ignore
                        const value = e.target.value;
                        if (isNaN(+value) || value > MAX_EVENT_CAPACITY) return;

                        field.onChange(e);
                      }}
                    />
                  )}
                />
                <OutlineButton
                  icon={<Plus />}
                  p={"$2"}
                  onPress={() => setValue("num_capacity", +allValues.num_capacity + 10)}
                  disabled={allValues.num_capacity >= MAX_EVENT_CAPACITY}
                />
              </XStack>

              {errors.num_capacity && <InputErrorText>{errors.num_capacity.message}</InputErrorText>}
            </InputGroupWrapper>
          </XStack>
        </YStack>

        <FilledButton
          onPress={handleSubmit(handleEventCreate)}
          disabled={!!Object.keys(errors).length}
        >
          {`${data?.id ? "Update" : "Create"} Event`}
        </FilledButton>
      </YStack>

      <RenderDateSelectionContent>
        <DateRangePicker
          initialDates={selectedScheduleRef.current}
          onSubmit={(...data) => {
            closeDateSelection();
            setValue("schedule", `${formatDateWithTimeString(data[0])} - ${formatDateWithTimeString(data[1])}`);
            selectedScheduleRef.current = data;
            clearErrors("schedule");
          }}
          onClose={closeDateSelection}
        />
      </RenderDateSelectionContent>

      <RenderMediaPreviewContent>
        <AssetPreviewDialog
          medias={previewableMedias}
          close={closeMediaPreview}
          currentSelectedMediaId={currentSelectedMediaRef.current}
        />
      </RenderMediaPreviewContent>

      <RenderInterestsDialog>
        <InterestsDialog
          title="Add tags"
          closeModal={closeInterestsDialog}
          onUpdateInterests={async ({ currentSelectedTags }) => {
            setSelectedTags(currentSelectedTags);
            if (currentSelectedTags.length) clearErrors("tags");
          }}
          preSelectedTags={selectedTags}
        />
      </RenderInterestsDialog>
    </>
  );
};

export default NewEvent;
