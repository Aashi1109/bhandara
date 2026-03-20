import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';
import '../widgets/media_preview.dart';
import '../widgets/button.dart';

class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({
    super.key,
    this.items = const [],
    this.initialIndex = 0,
  });

  static const String routePath = '/media-preview';
  final List<MediaItem> items;
  final int initialIndex;

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  bool _isOpen = true;

  @override
  Widget build(BuildContext context) {
    // Generate some mock data if empty for demo purposes (matching app/preview/page.tsx intent)
    final displayItems = widget.items.isNotEmpty
        ? widget.items
        : [
            MediaItem(
              id: '1',
              url: 'https://picsum.photos/seed/food1/600/400',
              thumbnail: 'https://picsum.photos/seed/food1/100/100',
              type: 'image',
              name: 'Signature Dish',
            ),
            MediaItem(
              id: '2',
              url: 'https://picsum.photos/seed/food2/600/400',
              thumbnail: 'https://picsum.photos/seed/food2/100/100',
              type: 'image',
              name: 'Chef Specials',
            ),
          ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.maximize2,
                    size: AppIconSizes.xl,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Media Preview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore our food event gallery',
                  style: TextStyle(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: AppButton(
                    label: 'Open Preview',
                    size: AppButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => setState(() => _isOpen = true),
                  ),
                ),
              ],
            ),
          ),
          if (_isOpen)
            Positioned.fill(
              child: AppMediaPreview(
                items: displayItems,
                initialIndex: widget.initialIndex,
                onClose: () => setState(() => _isOpen = false),
              ),
            ),
          // Back button if gallery is closed
          if (!_isOpen)
            Positioned(
              top: 60,
              left: 24,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.arrowLeft,
                    size: AppIconSizes.defaultSize,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
