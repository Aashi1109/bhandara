import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/card.dart';
import 'explore/explore_screen.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, this.event});

  static const String routePath = '/success';

  final Event? event;

  String get _imageUrl => event?.media?.isNotEmpty == true
      ? event!.media!.first.url
      : 'https://picsum.photos/seed/burrito/200/200';

  String get _categoryLabel {
    final tag = event?.tags?.isNotEmpty == true
        ? event!.tags!.first.name
        : null;
    if (tag != null && tag.isNotEmpty) return tag.toUpperCase();
    return 'EVENT';
  }

  String get _title => event?.name ?? 'Event';

  String get _locationLabel {
    final address = event?.location.address.trim();
    return address != null && address.isNotEmpty
        ? address
        : 'Location unavailable';
  }

  String get _timeRange {
    final currentEvent = event;
    if (currentEvent == null) return 'Time unavailable';
    final formatter = DateFormat('h:mm a');
    return '${formatter.format(currentEvent.startTime)} - ${formatter.format(currentEvent.endTime)}';
  }

  String get _participantLabel {
    final currentEvent = event;
    if (currentEvent == null) return '0';
    final count =
        currentEvent.stats?.participantCount ??
        currentEvent.participants?.length ??
        0;
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Check icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        size: AppIconSizes.hero,
                        color: AppColors.surface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Event Live!',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your contribution is now visible on the map.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Event card
                    AppCard(
                      padding: AppCardPadding.lg,
                      backgroundColor: AppColors.muted,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    Colors.grey,
                                    BlendMode.saturation,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: _imageUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              50,
                                            ),
                                          ),
                                          child: Text(
                                            _categoryLabel,
                                            style: const TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                              color: AppColors.surface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Just now',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.mapPin,
                                          size: AppIconSizes.s,
                                          color: AppColors.mutedForeground,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _locationLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.mutedForeground,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.only(top: 20),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.clock,
                                      size: AppIconSizes.m,
                                      color: AppColors.mutedForeground,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _timeRange,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.muted,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _participantLabel,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      LucideIcons.users,
                                      size: AppIconSizes.s,
                                      color: AppColors.mutedForeground
                                          .withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom buttons
              Column(
                children: [
                  AppButton(
                    size: AppButtonSize.xl,
                    fullWidth: true,
                    icon: const Icon(LucideIcons.map),
                    label: 'View on Map',
                    onPressed: () => context.go(ExploreScreen.routePath),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.xl,
                    fullWidth: true,
                    label: 'Done',
                    onPressed: () => context.go(ExploreScreen.routePath),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
