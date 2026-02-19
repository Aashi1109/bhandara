import React, { forwardRef , useRef } from "react";
import { type PopoverProps, Adapt, Popover } from "tamagui";

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
          <Popover.Sheet
            animation="quick"
            modal
            dismissOnSnapToBottom
          >
            <Popover.Sheet.Frame>
              <Adapt.Contents />
            </Popover.Sheet.Frame>
            <Popover.Sheet.Overlay
              bg="$shadowColor"
              animation="lazy"
              enterStyle={{ opacity: 0 }}
              exitStyle={{ opacity: 0 }}
            />
          </Popover.Sheet>
        </Adapt>
      )}

      {children}
    </Popover>
  );
});

PopoverWrapper.displayName = "PopoverWrapper";
