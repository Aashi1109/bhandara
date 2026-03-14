import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// A reusable animated tooltip wrapper for any target widget.
///
/// Usage:
/// ```dart
/// AnimatedTooltip(
///   message: 'Tap to continue',
///   child: Icon(Icons.info_outline),
/// )
/// ```
///
/// Behavior:
/// - `onTap`: shows tooltip briefly, then auto-hides.
/// - `onLongPress`: shows tooltip until press ends.
/// - Only one tooltip can be visible at a time across the app.
class AnimatedTooltip extends StatefulWidget {
  const AnimatedTooltip({
    super.key,
    required this.child,
    required this.message,
    this.position = TooltipPosition.top,
  });

  /// Target widget that triggers and anchors the tooltip.
  final Widget child;

  /// Text content shown inside the tooltip.
  final String message;

  /// Preferred tooltip direction relative to [child].
  final TooltipPosition position;

  @override
  State<AnimatedTooltip> createState() => _AnimatedTooltipState();
}

enum TooltipPosition { top, bottom }

class _TooltipDefaults {
  static const Duration showDuration = Duration(milliseconds: 150);
  static const Duration hideDuration = Duration(milliseconds: 100);
  static const Duration tapVisibleDuration = Duration(seconds: 2);

  static const double width = 200;
  static const double verticalOffsetTop = -50;
  static const double verticalOffsetBottom = 10;
  static const double scaleStart = 0.95;
  static const double scaleEnd = 1.0;

  static const EdgeInsets tooltipPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const EdgeInsets messagePadding = EdgeInsets.all(4);
  static const double borderRadius = 12;
}

class _AnimatedTooltipState extends State<AnimatedTooltip>
    with SingleTickerProviderStateMixin {
  static _AnimatedTooltipState? _activeTooltipState;

  OverlayEntry? _overlayEntry;
  Timer? _autoHideTimer;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _TooltipDefaults.showDuration,
      reverseDuration: _TooltipDefaults.hideDuration,
    );

    _scaleAnimation =
        Tween<double>(
          begin: _TooltipDefaults.scaleStart,
          end: _TooltipDefaults.scaleEnd,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  Future<void> _showTooltip() async {
    if (!mounted) return;
    _autoHideTimer?.cancel();

    if (_overlayEntry != null) {
      await _controller.forward();
      return;
    }

    if (_activeTooltipState != null && _activeTooltipState != this) {
      await _activeTooltipState!._hideTooltip();
      if (!mounted) return;
    }

    _activeTooltipState = this;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    await _controller.forward();
  }

  Future<void> _hideTooltip() async {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    if (_overlayEntry == null) return;

    await _controller.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_activeTooltipState == this) {
      _activeTooltipState = null;
    }
  }

  Future<void> _showForDuration(Duration duration) async {
    await _showTooltip();
    _autoHideTimer = Timer(duration, () {
      _hideTooltip();
    });
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    final Size size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: _TooltipDefaults.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: widget.position == TooltipPosition.top
              ? Offset(
                  -(_TooltipDefaults.width / 2) + size.width / 2,
                  _TooltipDefaults.verticalOffsetTop,
                )
              : Offset(
                  -(_TooltipDefaults.width / 2) + size.width / 2,
                  size.height + _TooltipDefaults.verticalOffsetBottom,
                ),
          child: ScaleTransition(
            scale: _scaleAnimation,
            alignment: widget.position == TooltipPosition.top
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    padding: _TooltipDefaults.tooltipPadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        _TooltipDefaults.borderRadius,
                      ),
                      border: Border.all(
                        color: AppColors.surface.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        _TooltipDefaults.borderRadius,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: _TooltipDefaults.messagePadding,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.8),
                          ),
                          child: Text(
                            widget.message,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onLongPress: _showTooltip,
        onLongPressEnd: (_) => _hideTooltip(),
        onTap: () async {
          await _showForDuration(_TooltipDefaults.tapVisibleDuration);
        },
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    if (_activeTooltipState == this) {
      _activeTooltipState = null;
    }
    _controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }
}
