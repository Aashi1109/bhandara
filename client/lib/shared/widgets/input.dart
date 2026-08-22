import 'package:flutter/material.dart';
import '../theme/theme.dart';
import 'input_error.dart';
import 'input_label.dart';

export 'input_error.dart';
export 'input_label.dart';

enum AppInputType { text, email }

class ValidationRule<T> {
  const ValidationRule({required this.value, required this.message});

  final T value;
  final String message;
}

class InputValidations {
  const InputValidations({
    this.required,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.validate,
  });

  /// Can be [bool] (default message), [String] (shortcut for message),
  /// or [ValidationRule<bool>] (object for message).
  final dynamic required;

  /// Can be [int] (raw value) or [ValidationRule<int>] (value + custom message).
  final dynamic minLength;

  /// Can be [int] (raw value) or [ValidationRule<int>] (value + custom message).
  final dynamic maxLength;

  /// Can be [RegExp] (raw pattern) or [ValidationRule<RegExp>] (pattern + custom message).
  final dynamic pattern;

  final String? Function(String?)? validate;
}

class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    this.type = AppInputType.text,
    this.label,
    this.placeholder,
    this.error,
    this.icon,
    this.rightElement,
    this.controller,
    this.onChanged,
    this.obscureText = false,
    this.keyboardType,
    this.height = 56,
    this.borderRadius = 20,
    this.contentPadding,
    this.elementSpacing = 16,
    this.textFieldContentPadding,
    this.trailingSpacing = 6,
    this.backgroundColor,
    this.hasBorder = true,
    this.validations,
    this.onValidationError,
    this.maxLines = 1,
    this.minLines,
    this.focusNode,
    this.autofocus = false,
    this.uppercaseLabel = false,
    this.labelStyle,
    this.readOnly = false,
    this.value,
    this.onTap,
    this.showErrorText = true,
    this.labelPadding = EdgeInsets.zero,
    this.textStyle,
    this.placeholderStyle,
  });

  final AppInputType type;
  final String? label;
  final String? placeholder;
  final String? error;
  final Widget? icon;
  final Widget? rightElement;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final TextInputType? keyboardType;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final double elementSpacing;
  final EdgeInsetsGeometry? textFieldContentPadding;
  final double trailingSpacing;
  final Color? backgroundColor;
  final bool hasBorder;
  final InputValidations? validations;
  final ValueChanged<String?>? onValidationError;
  final int? maxLines;
  final int? minLines;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool uppercaseLabel;
  final TextStyle? labelStyle;
  final bool readOnly;
  final String? value;
  final VoidCallback? onTap;
  final bool showErrorText;
  final EdgeInsetsGeometry labelPadding;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  static final RegExp _emailPattern = RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  String? _internalError;

  T? _extractRuleValue<T>(dynamic rule) {
    if (rule is ValidationRule<T>) return rule.value;
    if (rule is T) return rule;
    return null;
  }

  String _extractRuleMessage(dynamic rule, String defaultMessage) {
    if (rule is ValidationRule) return rule.message;
    if (rule is String) return rule;
    return defaultMessage;
  }

  InputValidations? _effectiveValidations() {
    final rules = widget.validations;
    if (widget.type != AppInputType.email) {
      return rules;
    }

    return InputValidations(
      required: rules?.required ?? 'Email is required',
      minLength: rules?.minLength,
      maxLength: rules?.maxLength,
      pattern:
          rules?.pattern ??
          ValidationRule(
            value: _emailPattern,
            message: 'Invalid email address',
          ),
      validate: rules?.validate,
    );
  }

  void _validate(String value) {
    final rules = _effectiveValidations();
    if (rules == null) {
      return;
    }
    String? newError;

    // Required check: exactly matches react-hook-form logic
    if (rules.required != null) {
      final isRequired = rules.required is bool
          ? rules.required
          : rules.required is String
          ? true
          : _extractRuleValue<bool>(rules.required) ?? false;

      if (isRequired && value.isEmpty) {
        newError = _extractRuleMessage(
          rules.required,
          '${widget.label ?? 'Field'} is required',
        );
      }
    }

    // minLength check
    if (newError == null && rules.minLength != null) {
      final min = _extractRuleValue<int>(rules.minLength);
      if (min != null && value.length < min) {
        newError = _extractRuleMessage(
          rules.minLength,
          '${widget.label ?? 'Field'} must be at least $min characters',
        );
      }
    }

    // maxLength check
    if (newError == null && rules.maxLength != null) {
      final max = _extractRuleValue<int>(rules.maxLength);
      if (max != null && value.length > max) {
        newError = _extractRuleMessage(
          rules.maxLength,
          '${widget.label ?? 'Field'} must be at most $max characters',
        );
      }
    }

    // pattern check
    if (newError == null && rules.pattern != null) {
      final regex = _extractRuleValue<RegExp>(rules.pattern);
      if (regex != null && !regex.hasMatch(value)) {
        newError = _extractRuleMessage(rules.pattern, 'Invalid format');
      }
    }

    // Custom validate function
    if (newError == null && rules.validate != null) {
      newError = rules.validate!(value);
    }

    if (_internalError != newError) {
      setState(() {
        _internalError = newError;
      });
      if (widget.onValidationError != null) {
        widget.onValidationError!(newError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    final displayError = widget.error ?? _internalError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (widget.label != null)
          AppInputLabel(
            label: widget.label!,
            uppercase: widget.uppercaseLabel,
            style: widget.labelStyle,
            padding: widget.labelPadding,
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: widget.height,
            padding: widget.contentPadding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppColors.surface,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.hasBorder
                  ? Border.all(
                      color: displayError != null
                          ? AppColors.error
                          : AppColors.border,
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: widget.elementSpacing,
              children: [
                if (widget.icon != null) ...[
                  IconTheme(
                    data: const IconThemeData(
                      color: AppColors.mutedForeground,
                      size: AppIconSizes.defaultSize,
                    ),
                    child: widget.icon!,
                  ),
                ],
                Expanded(
                  child: widget.readOnly
                      ? Text(
                          widget.value?.isNotEmpty == true
                              ? widget.value!
                              : widget.placeholder ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: widget.value?.isNotEmpty == true
                              ? widget.textStyle ?? typography.bodyMD
                              : widget.placeholderStyle ??
                                    typography.bodyMD.copyWith(
                                      color: AppColors.mutedForeground
                                          .withValues(alpha: 0.5),
                                    ),
                        )
                      : TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          autofocus: widget.autofocus,
                          onChanged: (value) {
                            _validate(value);
                            if (widget.onChanged != null) {
                              widget.onChanged!(value);
                            }
                          },
                          obscureText: widget.obscureText,
                          keyboardType:
                              widget.keyboardType ??
                              (widget.type == AppInputType.email
                                  ? TextInputType.emailAddress
                                  : null),
                          maxLines: widget.maxLines,
                          minLines: widget.minLines,
                          style:
                              widget.textStyle ??
                              typography.bodyMD.copyWith(
                                color: AppColors.primary,
                              ),
                          decoration: InputDecoration(
                            hintText: widget.placeholder,
                            hintStyle:
                                widget.placeholderStyle ??
                                typography.bodyMD.copyWith(
                                  color: AppColors.mutedForeground.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                            border: InputBorder.none,
                            contentPadding:
                                widget.textFieldContentPadding ??
                                EdgeInsets.symmetric(
                                  horizontal: widget.icon != null ? 12 : 20,
                                ),
                          ),
                        ),
                ),
                if (widget.rightElement != null) ...[
                  widget.rightElement!,
                  if (widget.trailingSpacing > 0)
                    SizedBox(width: widget.trailingSpacing),
                ],
              ],
            ),
          ),
        ),
        if (displayError != null && widget.showErrorText)
          AppInputError(message: displayError),
      ],
    );
  }
}
