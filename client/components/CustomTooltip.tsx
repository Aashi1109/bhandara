import React from "react";
import { type PopoverContentTypeProps, type TooltipProps, Theme, Tooltip } from "tamagui";

const CustomTooltip = ({
  children,
  trigger,
  tooltipConfig,
  tooltipContentConfig
}: {
  children: React.ReactNode;
  trigger: React.ReactNode;
  tooltipConfig?: Partial<TooltipProps>;
  tooltipContentConfig?: Partial<PopoverContentTypeProps>;
}) => {
  return (
    <Tooltip
      offset={10}
      unstyled
      {...tooltipConfig}
    >
      <Tooltip.Trigger>{trigger}</Tooltip.Trigger>
      <Tooltip.Content
        unstyled
        {...tooltipContentConfig}
      >
        <Theme name={"dark"}>{children}</Theme>
      </Tooltip.Content>
    </Tooltip>
  );
};

export default CustomTooltip;
