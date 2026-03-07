import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme.dart';
import '../widgets/input.dart';
import '../widgets/bottom_nav.dart';

import 'explore.dart';
import 'event_detail.dart';

class SearchScreen extends StatelessWidget {
  static const String routePath = '/search';
  const SearchScreen({super.key});

  static final _events = [
    _Event(
      1,
      'Tuesday Taco Pop-up',
      'Spicy bean & corn tacos with salsa',
      '0.3 mi',
      '45m left',
      'FREE',
      'https://picsum.photos/seed/tacos/300/300',
      'urgent',
    ),
    _Event(
      2,
      'Elote & Chips Stand',
      'Fresh corn cups and homemade chips',
      '0.8 mi',
      'Just Started',
      null,
      'https://picsum.photos/seed/corn/300/300',
      'new',
    ),
    _Event(
      3,
      'Community Garden Lunch',
      'Leftover catering, plant-based tacos',
      '1.2 mi',
      '2h remaining',
      'VEGAN',
      'https://picsum.photos/seed/garden/300/300',
      'normal',
    ),
    _Event(
      4,
      'Downtown Food Drive',
      'Surplus grocery distribution',
      '0.1 mi',
      'Ended 10m ago',
      'CLOSED',
      'https://picsum.photos/seed/box/300/300',
      'closed',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.9),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(ExploreScreen.routePath),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.arrowLeft,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppInput(
                            placeholder: 'Search...',
                            icon: const Icon(LucideIcons.search, size: 20),
                            height: 48,
                            borderRadius: 50,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                LucideIcons.slidersHorizontal,
                                size: 24,
                                color: AppColors.primary,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Filter chips
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _chipBtn('All Results', true),
                          const SizedBox(width: 8),
                          _chipBtn('Nearest', false),
                          const SizedBox(width: 8),
                          _chipBtn('Closing Soon', false),
                          const SizedBox(width: 8),
                          _chipBtn('Vegan', false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    children: [
                      // Results header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '12 events found',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.go(ExploreScreen.routePath),
                              child: const Text(
                                'Map View',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Event cards
                      ...List.generate(_events.length, (i) {
                        final e = _events[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () => context.go(
                              EventDetailScreen.routePath.replaceAll(
                                ':id',
                                e.id.toString(),
                              ),
                            ),
                            child: _buildEventCard(e),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const AppBottomNav(),
        ],
      ),
    );
  }

  Widget _buildEventCard(_Event e) {
    final isClosed = e.status == 'closed';
    return Opacity(
      opacity: isClosed ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  children: [
                    ColorFiltered(
                      colorFilter: isClosed
                          ? const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            )
                          : const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.multiply,
                            ),
                      child: CachedNetworkImage(
                        imageUrl: e.image,
                        fit: BoxFit.cover,
                        width: 96,
                        height: 96,
                      ),
                    ),
                    if (e.tag != null && !isClosed)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: e.tag == 'VEGAN'
                                ? AppColors.accent
                                : AppColors.primary.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            e.tag!,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
                    if (isClosed)
                      Container(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        child: const Center(
                          child: Text(
                            'CLOSED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Icon(
                        LucideIcons.heart,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.navigation,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            e.distance,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: e.status == 'urgent'
                              ? const Color(0xFFFFFBEB)
                              : e.status == 'new'
                              ? const Color(0xFFECFDF5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            if (e.status == 'urgent')
                              Icon(
                                LucideIcons.timer,
                                size: 14,
                                color: const Color(0xFFD97706),
                              ),
                            if (e.status == 'new')
                              Icon(
                                LucideIcons.checkCircle2,
                                size: 14,
                                color: const Color(0xFF059669),
                              ),
                            if (e.status == 'urgent' || e.status == 'new')
                              const SizedBox(width: 4),
                            Text(
                              e.time,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: e.status == 'urgent'
                                    ? const Color(0xFFD97706)
                                    : e.status == 'new'
                                    ? const Color(0xFF059669)
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _chipBtn(String text, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(50),
        border: selected ? null : Border.all(color: AppColors.border),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _Event {
  final int id;
  final String title;
  final String description;
  final String distance;
  final String time;
  final String? tag;
  final String image;
  final String status;

  _Event(
    this.id,
    this.title,
    this.description,
    this.distance,
    this.time,
    this.tag,
    this.image,
    this.status,
  );
}
