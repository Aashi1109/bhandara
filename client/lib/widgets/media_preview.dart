import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/theme.dart';

class MediaItem {
  MediaItem({
    required this.id,
    required this.url,
    required this.thumbnail,
    required this.type,
    required this.name,
  });

  final String id;
  final String url;
  final String thumbnail;
  final String type; // 'image' or 'video'
  final String name;
}

class AppMediaPreview extends StatefulWidget {
  const AppMediaPreview({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onClose,
  });

  final List<MediaItem> items;
  final int initialIndex;
  final VoidCallback? onClose;

  @override
  State<AppMediaPreview> createState() => _AppMediaPreviewState();
}

class _AppMediaPreviewState extends State<AppMediaPreview> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.x, size: 20),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      widget.items[_currentIndex].name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentIndex + 1} OF ${widget.items.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.download, size: 20),
                ),
              ],
            ),
          ),

          // Main View
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: item.type == 'image'
                              ? ColorFiltered(
                            colorFilter: const ColorFilter.matrix([
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                            child: Image.network(
                              item.url,
                              fit: BoxFit.contain,
                            ),
                          )
                              : Container(
                            color: AppColors.muted,
                            child: const Center(
                              child: Icon(LucideIcons.play, size: 64),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Navigation Arrows (simplified for mobile)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _navButton(LucideIcons.chevronLeft, () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _navButton(LucideIcons.chevronRight, () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Reactions
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _reactionItem(LucideIcons.thumbsUp, '12'),
                      _reactionItem(LucideIcons.heart, '5'),
                      _reactionItem(LucideIcons.smile, '3'),
                      const SizedBox(width: 8),
                      const SizedBox(
                        height: 20,
                        child: VerticalDivider(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.share2, size: 16),
                      const SizedBox(width: 16),
                      const Icon(LucideIcons.plus, size: 16),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Thumbnails
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    separatorBuilder: (context, index) =>
                    const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () => _pageController.jumpToPage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              item.thumbnail,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _reactionItem(IconData icon, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
