import 'package:flutter/material.dart';
import '../theme/theme.dart';

class AppTabItem<T> {
  const AppTabItem({required this.label, required this.value, this.icon});
  final String label;
  final T value;
  final String? icon;
}

class AppTabs<T> extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.items,
    required this.currentValue,
    required this.onChanged,
    this.height = 56,
  });

  final List<AppTabItem<T>> items;
  final T currentValue;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        final isSelected = currentValue == item.value;
        final isLast = items.last == item;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 12, left: 0),
            child: GestureDetector(
              onTap: () => onChanged(item.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: height,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Text(
                        item.icon!,
                        style: TextStyle(
                          fontSize: 18,
                          color: isSelected
                              ? AppColors.surface
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.surface
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
