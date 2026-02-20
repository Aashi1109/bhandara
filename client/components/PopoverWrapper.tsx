import React, { forwardRef , useRef } from "react";
import { type PopoverProps, Adapt, Popover, Sheet } from "tamagui";

interface IProps extends PopoverProps {
  children?: React.ReactNode;
  shouldAdapt?: boolean;
  trigger?: React.ReactNode;
  asChild?: boolean;
}

export const PopoverWrapper = forwardRef<any, IProps>(({ children, shouldAdapt, trigger, asChild, ...props }, ref) => {
  delete (props as any).ref;

  return (
    <Popover
      allowFlip
      stayInFrame
      offset={15}
      resize
      ref={ref}
      {...props}
    >
      <Popover.Trigger asChild={asChild}>{trigger}</Popover.Trigger>

      {shouldAdapt && (
        <Adapt
          when="gtMd"
          platform="touch"
        >
          <Sheet
            transition="quick"
            modal
            dismissOnSnapToBottom
          >
            <Sheet.Frame>
              <Adapt.Contents />
            </Sheet.Frame>
            <Sheet.Overlay
              bg="$shadowColor"
              transition="lazy"
              enterStyle={{ opacity: 0 }}
              exitStyle={{ opacity: 0 }}
            />
          </Sheet>
        </Adapt>
      )}

      {children}
    </Popover>
  );
});

PopoverWrapper.displayName = "PopoverWrapper";
