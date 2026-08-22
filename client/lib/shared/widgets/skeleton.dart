import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1200),
  }) : assert(
         shape != BoxShape.circle || borderRadius == null,
         'borderRadius cannot be provided for circular skeletons.',
       );

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy `late final` initializer would run on first
    // read, and if that read is dispose(), `vsync: this` looks up TickerMode
    // on an already-deactivated element and throws.
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.baseColor ?? AppColors.muted.withValues(alpha: 0.82);
    final highlightColor =
        widget.highlightColor ?? AppColors.surface.withValues(alpha: 0.92);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedWidth =
              constraints.hasBoundedWidth && constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (widget.width ?? 160);
          final shimmerWidth = resolvedWidth * 0.55;
          final shimmerTravel = resolvedWidth + shimmerWidth;

          return ClipRRect(
            borderRadius: widget.shape == BoxShape.circle
                ? BorderRadius.circular(999)
                : (widget.borderRadius ?? BorderRadius.circular(16)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: widget.shape,
                    borderRadius: widget.shape == BoxShape.circle
                        ? null
                        : widget.borderRadius,
                  ),
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Transform.translate(
                      offset: Offset(
                        (_controller.value * shimmerTravel) - shimmerWidth,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: shimmerWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  highlightColor.withValues(alpha: 0),
                                  highlightColor,
                                  highlightColor.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AppSkeletonLine extends StatelessWidget {
  const AppSkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
      baseColor: baseColor,
      highlightColor: highlightColor,
    );
  }
}
