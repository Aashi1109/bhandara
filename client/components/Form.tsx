import { type Control, Controller } from "react-hook-form";
import { type YStack, Input, Paragraph, Text, XStack, View, styled } from "tamagui";
import React from "react";

export const StyledInput = styled(Input, {
  name: "StyledInput",
  variants: {
    disabled: {
      true: {
        opacity: 0.5,
        bg: "$color6",
        cursor: "not-allowed",
        pointerEvents: "none",
        color: "$color11",
        placeholderTextColor: "$color11"
      }
    },
    error: {
      true: {
        borderColor: "$red10"
      },
      false: {
        borderColor: "$borderColor"
      }
    }
  } as const
});

export const InputGroupWrapper = styled(View, {
  name: "InputGroupWrapper",
  gap: "$2",
  flex: 1,
  shrink: 0,
  maxH: "min-content"
});

export const InputLabel = styled(Text, {
  name: "InputLabel",
  fontSize: "$3"
});

export const InputLabelWrapper = styled(XStack, {
  name: "InputLabelWrapper",
  gap: "$2",
  justify: "space-between",
  items: "center"
});

export const InputLabelRightText = styled(Paragraph, {
  name: "InputLabelRightText",
  size: "$1",
  color: "$color10"
});

export const InputErrorText = styled(Text, {
  name: "InputErrorText",
  color: "$red10",
  fontSize: "$1",
  width: "auto"
});

export const InputFieldWrapper = styled(XStack, {
  name: "InputFieldWrapper",
  borderWidth: 1,
  rounded: "$4",
  overflow: "hidden",
  focusWithinStyle: { outlineWidth: 2, outlineColor: "$color7", outlineStyle: "solid" },
  gap: "$3",
  position: "relative",
  items: "center",
  px: "$3.5"
});

export const InputField = styled(StyledInput, {
  name: "InputField",
  rounded: 0,
  borderWidth: 0,
  borderColor: "transparent",
  display: "flex",
  flex: 1,
  focusVisibleStyle: { outline: "none", outlineColor: "transparent", outlineWidth: 0 },
  outline: "none",
  px: 0,
  focusStyle: null,
  focusWithinStyle: null
});

export const TextareaField = styled(InputField, {
  name: "TextareaField",
  rounded: 0,
  borderWidth: 0,
  borderColor: "transparent",
  display: "flex",
  flex: 1,
  focusVisibleStyle: { outline: "none", outlineColor: "transparent", outlineWidth: 0 },
  outline: "none",
  px: 0,
  focusStyle: null,
  focusWithinStyle: null
});

export const InputGroup = ({
  control,
  rules,
  error,
  placeHolder,
  name,
  label,
  rightLabel,
  onChange,
  inputProps,
  iconBefore,
  iconAfter,
  containerProps
}: {
  control: Control<any>;
  rules?: Record<string, any>;
  error: any;
  placeHolder: string;
  name: string;
  label?: string;
  rightLabel?: string;
  onChange?: (value: any) => void;
  inputProps?: React.ComponentProps<typeof Input>;
  iconBefore?: React.ReactNode;
  iconAfter?: React.ReactNode;
  containerProps?: React.ComponentProps<typeof YStack>;
}) => {
  return (
    <InputGroupWrapper {...(containerProps || {})}>
      {(label || rightLabel) && (
        <InputLabelWrapper>
          {label && <InputLabel>{label}</InputLabel>}
          {rightLabel && <InputLabelRightText>{rightLabel}</InputLabelRightText>}
        </InputLabelWrapper>
      )}
      <Controller
        control={control}
        name={name}
        rules={rules}
        render={({ field }) => (
          <InputFieldWrapper
            bg={inputProps?.disabled ? "$color6" : inputProps?.bg || "$background"}
            borderColor={error ? "$red8" : "$borderColor"}
          >
            {iconBefore}
            <InputField
              value={field.value}
              placeholder={placeHolder}
              error={!!error}
              autoComplete={inputProps?.secureTextEntry ? "off" : inputProps?.autoComplete}
              onChangeText={(value) => {
                field.onChange(value);
                onChange?.(value);
              }}
              {...(inputProps || {})}
            />
            {iconAfter}
          </InputFieldWrapper>
        )}
      />
      {error && <InputErrorText>{error}</InputErrorText>}
    </InputGroupWrapper>
  );
};
