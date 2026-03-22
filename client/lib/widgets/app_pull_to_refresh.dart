import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppPullToRefresh extends StatelessWidget {
  const AppPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.edgeOffset = 0,
    this.displacement = 40,
    this.color = AppColors.primary,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double edgeOffset;
  final double displacement;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: color,
      edgeOffset: edgeOffset,
      displacement: displacement,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
