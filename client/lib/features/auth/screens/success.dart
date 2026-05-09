import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../events/models/event.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/button.dart';
import '../../../shared/widgets/card.dart';
import '../../explore/screens/explore_screen.dart';

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
    final timeFormatter = DateFormat('h:mm a');
    final start = currentEvent.startTime.toLocal();
    final end = currentEvent.endTime.toLocal();
    return '${timeFormatter.format(start)} - ${timeFormatter.format(end)}';
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
    final typography = context.appTypography;
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
                    Text(
                      'Event Live!',
                      style: typography.heading1.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your contribution is now visible on the map.',
                      style: typography.bodyLG.copyWith(
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
                                            style: typography.overline.copyWith(
                                              color: AppColors.surface,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Just now',
                                          style: typography.labelSM.copyWith(
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _title,
                                      style: typography.titleMD.copyWith(
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
                                            style: typography.bodySM.copyWith(
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
                                      style: typography.bodySMStrong.copyWith(
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
                                          style: typography.labelXSStrong
                                              .copyWith(
                                                color:
                                                    AppColors.mutedForeground,
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
