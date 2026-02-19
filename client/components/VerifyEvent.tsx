import React, { useMemo, useState } from "react";
import type { IEvent, IBaseUser } from "@/definitions/types";
import { useAuth } from "@/contexts/AuthContext";
import { OutlineButton, FilledButton } from "@/components/ui/Buttons";
import { CardWrapper, DialogContent, DialogTitle } from "@/components/ui/common-styles";
import { type ButtonProps, type YStackProps, Dialog, H6, Text, View, ViewProps } from "tamagui";
import { useDialog } from "@/hooks/useModal";
import VerificationMap from "@/components/maps/VerificationMap";
import { EVENT_VERIFY_RADIUS_M } from "@/constants/global";
import { askForLocation, haversineDistanceInM } from "@/utils/location";
import { verifyEvent } from "@/common/api/events.action";
import { useToastController } from "@tamagui/toast";
import { Check } from "@tamagui/lucide-icons";
import CustomTooltip from "@/components/CustomTooltip";
import { formatDateWithTimeString } from "@/utils/date.utils";
import { SpinningLoader } from "@/components/ui/Loaders";
import { formatDistance } from "@/helpers";
import { Badge } from "./ui/Badge";

const VerifyEvent = ({
  event,
  onVerified,
  buttonStyles
}: {
  event: IEvent;
  onVerified: (verifier: { user: IBaseUser; verifiedAt: string }) => void;
  buttonStyles?: ButtonProps | YStackProps;
}) => {
  const { user } = useAuth();
  const isCreator = user?.id === event.createdBy;
  const existingVerifier = event.verifiers.find((v) => {
    const id = typeof v.user === "string" ? v.user : v.user.id;
    return id === user?.id;
  });

  const { open, close, RenderContent } = useDialog();
  const toast = useToastController();
  const [userCoords, setUserCoords] = useState<[number, number] | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const distanceBetweenUserAndEvent = useMemo(
    () =>
      userCoords &&
      haversineDistanceInM(
        { latitude: userCoords[1], longitude: userCoords[0] },
        { latitude: event.location.latitude!, longitude: event.location.longitude! }
      ),
    [userCoords, event.location.latitude, event.location.longitude]
  );

  if (isCreator) return null;

  const canVerify = (distanceBetweenUserAndEvent || 0) <= EVENT_VERIFY_RADIUS_M;

  const handleVerify = async () => {
    if (!userCoords) return;
    setIsSubmitting(true);
    try {
      await verifyEvent(event.id, {
        latitude: userCoords[1],
        longitude: userCoords[0]
      });
      onVerified({ user: user as IBaseUser, verifiedAt: new Date().toISOString() });
      close();
    } catch (error: any) {
      toast.show(error?.message || "Failed to verify");
    } finally {
      setIsSubmitting(false);
    }
  };

  const handlePressVerifyButton = async () => {
    try {
      setIsSubmitting(true);
      const location = await askForLocation();
      if (location) {
        setUserCoords([location.coords.longitude, location.coords.latitude]);
        open();
      }
    } catch (error: any) {
      toast.show(error?.message || "Failed to get location");
    } finally {
      setIsSubmitting(false);
    }
  };

  const button = existingVerifier ? (
    <CustomTooltip
      trigger={
        <Badge
          width="auto"
          flexDirection="row"
          outline-success
        >
          <Badge.Icon>
            <Check size={16} />
          </Badge.Icon>
          <Badge.Text fontSize={"$3"}>Verified</Badge.Text>
        </Badge>
      }
    >
      <CardWrapper
        rounded="$3"
        p="$2"
      >
        <Text fontSize="$2">Verified at {formatDateWithTimeString(existingVerifier.verifiedAt as any)}</Text>
      </CardWrapper>
    </CustomTooltip>
  ) : (
    <OutlineButton
      size={"medium"}
      width="auto"
      onPress={handlePressVerifyButton}
      px="$2"
      icon={isSubmitting ? <SpinningLoader /> : <Check size={16} />}
      {...buttonStyles}
    >
      <Text>Verify Event</Text>
    </OutlineButton>
  );

  return (
    <>
      {button}
      <RenderContent>
        <DialogTitle>Verify Event</DialogTitle>

        <VerificationMap
          eventCoords={[event.location.longitude!, event.location.latitude!]}
          eventName={event.name}
          userCoords={userCoords || [0, 0]}
          radius={EVENT_VERIFY_RADIUS_M}
          onUserLocationChange={setUserCoords}
          zoomLevel={17}
        />

        <Text
          color={canVerify ? "$green10" : "$red10"}
          fontSize="$2"
        >
          You are {formatDistance(distanceBetweenUserAndEvent || 0)} away from the event
        </Text>
        <FilledButton
          size="medium"
          disabled={!canVerify || isSubmitting}
          onPress={handleVerify}
          iconAfter={isSubmitting ? <SpinningLoader /> : undefined}
        >
          Verify Now
        </FilledButton>
      </RenderContent>
    </>
  );
};

export default VerifyEvent;
