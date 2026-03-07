import 'package:flutter/material.dart';
import '../theme/theme.dart';

class ValidationRule<T> {
  final T value;
  final String message;

  const ValidationRule({required this.value, required this.message});
}

class InputValidations {
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

  const InputValidations({
    this.required,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.validate,
  });
}

class AppInput extends StatefulWidget {
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
  final Color? backgroundColor;
  final bool hasBorder;
  final InputValidations? validations;
  final ValueChanged<String?>? onValidationError;
  final int? maxLines;
  final int? minLines;

  const AppInput({
    super.key,
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
    this.borderRadius = 16,
    this.backgroundColor,
    this.hasBorder = true,
    this.validations,
    this.onValidationError,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
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

  void _validate(String value) {
    if (widget.validations == null) return;

    final rules = widget.validations!;
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
    final displayError = widget.error ?? _internalError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              widget.label!.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          height: widget.height,
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
            children: [
              if (widget.icon != null) ...[
                const SizedBox(width: 16),
                IconTheme(
                  data: const IconThemeData(
                    color: AppColors.mutedForeground,
                    size: 20,
                  ),
                  child: widget.icon!,
                ),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: (value) {
                    _validate(value);
                    if (widget.onChanged != null) {
                      widget.onChanged!(value);
                    }
                  },
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedForeground.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.icon != null ? 12 : 20,
                    ),
                  ),
                ),
              ),
              if (widget.rightElement != null) ...[
                widget.rightElement!,
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (displayError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              displayError,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
