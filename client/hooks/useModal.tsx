import { useState, useMemo } from "react";
import { type DialogContentProps, Adapt, AnimatePresence, Sheet, Unspaced, Dialog } from "tamagui";
import { DialogContent as StandardDialogContent } from "@/components/ui/common-styles";
import { X } from "@tamagui/lucide-icons";
import { OutlineButton } from "@/components/ui/Buttons";

interface UseDialogProps {
  disableAdapt?: boolean;
  hideOnOutsideClick?: boolean;
  defaultOpen?: boolean;
}

interface UseDialogReturn {
  isOpen: boolean;
  open: () => void;
  close: () => void;
  toggle: () => void;
  RenderContent: React.FC<{ children: React.ReactNode }>;
}

// Create the base dialog component outside the hook
const createDialogContent = (
  isOpen: boolean,
  setIsOpen: (open: boolean) => void,
  disableAdapt: boolean,
  hideOnOutsideClick: boolean
) => {
  const DialogContent: React.FC<{
    children: React.ReactNode;
    styles?: DialogContentProps;
    showCloseButton?: boolean;
  }> = ({ children, styles, showCloseButton = true }) => (
    <Dialog
      modal
      open={isOpen}
      onOpenChange={setIsOpen}
    >
      {!disableAdapt && (
        <Adapt
          when="gtMd"
          platform="touch"
        >
          <Sheet
            transition="quick"
            modal
            dismissOnSnapToBottom
          >
            <Sheet.Frame
              p={"$4"}
              gap={"$4"}
              z={200}
            >
              <Adapt.Contents />
            </Sheet.Frame>
            <Sheet.Overlay
              bg="$shadow6"
              transition="lazy"
              enterStyle={{ opacity: 0 }}
              exitStyle={{ opacity: 0 }}
              z={199}
            />
          </Sheet>
        </Adapt>
      )}

      <Dialog.Portal>
        <Dialog.Overlay
          key="overlay"
          bg="$shadow6"
          animateOnly={["transform", "opacity"]}
          transition={[
            "quicker",
            {
              opacity: {
                overshootClamping: true
              }
            }
          ]}
          enterStyle={{ opacity: 0 }}
          exitStyle={{ opacity: 0 }}
          onPress={() => {
            if (hideOnOutsideClick) {
              setIsOpen(false);
            }
          }}
          z={9999}
        />
        <StandardDialogContent
          minW={400}
          key="content"
          {...styles}
          position="relative"
        >
          {children}

          {showCloseButton && (
            <Unspaced>
              <Dialog.Close asChild>
                <OutlineButton
                  p={"$2"}
                  t={"$4"}
                  r={"$4"}
                  position="absolute"
                  rounded={"$2"}
                  onPress={() => setIsOpen(false)}
                  iconAfter={<X />}
                />
              </Dialog.Close>
            </Unspaced>
          )}
        </StandardDialogContent>
      </Dialog.Portal>
    </Dialog>
  );

  return DialogContent;
};

export function useDialog({
  disableAdapt = false,
  hideOnOutsideClick = false,
  defaultOpen = false
}: UseDialogProps = {}): UseDialogReturn {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  const open = () => setIsOpen(true);
  const close = () => setIsOpen(false);
  const toggle = () => setIsOpen((prev) => !prev);

  // Memoize the DialogContent component
  const RenderContent = useMemo(
    () => createDialogContent(isOpen, setIsOpen, disableAdapt, hideOnOutsideClick),
    [isOpen, setIsOpen, disableAdapt, hideOnOutsideClick]
  );

  return {
    isOpen,
    open,
    close,
    toggle,
    RenderContent
  };
}
