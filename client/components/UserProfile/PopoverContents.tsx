import { useAuth } from "@/contexts/AuthContext";
import { Calendar, LogOut, Settings , User } from "@tamagui/lucide-icons";
import { useRouter } from "expo-router";
import React, { useCallback } from "react";

import ConfirmationDialog from "../ConfirmationDialog";
import { useDialog } from "@/hooks/useModal";
import { useToastController } from "@tamagui/toast";
import PopoverMenuList from "../PopoverMenuList";

const tabs = [
  {
    label: "Profile",
    icon: <User />
  },
  {
    label: "Settings",
    icon: <Settings />
  },
  {
    label: "My Events",
    icon: <Calendar />
  }
];

const groups = [
  {
    label: "General",
    tabs: tabs
  },
  {
    label: "Actions",
    tabs: [
      {
        label: "Logout",
        icon: <LogOut />,
        color: "$red11"
      }
    ]
  }
];

const UserProfilePopover = ({}) => {
  const { logout } = useAuth();
  const router = useRouter();
  const toastController = useToastController();

  const { open, close, RenderContent } = useDialog();

  const handleActionClick = useCallback(
    (action: string) => {
      switch (action) {
        case "logout":
          open();
          break;
        case "settings":
          router.push("/profile?tab=settings");
          break;
        case "my-events":
          router.push("/profile?tab=my-events");
          break;
        case "profile":
          router.push("/profile?tab=info");
          break;
      }
    },
    [router]
  );

  const handleLogout = async () => {
    try {
      await logout();
      close();
    } catch (error: any) {
      console.error(error);
      toastController.show(error?.error?.message || "Failed to logout");
    }
  };

  return (
    <>
      <PopoverMenuList
        groups={groups}
        handleActionClick={handleActionClick}
      />

      <RenderContent>
        <ConfirmationDialog
          title="Logout"
          description="Are you sure you want to logout?"
          onClose={() => {}}
          onConfirm={handleLogout}
          asDanger
        />
      </RenderContent>
    </>
  );
};

export default UserProfilePopover;
