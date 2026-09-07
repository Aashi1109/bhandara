import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../events/models/event.dart';
import '../../events/screens/event_detail.dart';
import '../../events/utils/event_share.dart';
import '../../explore/screens/explore_screen.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, this.event});

  static const String routePath = '/success';

  final Event? event;

  String get _title => event?.name ?? 'Event';

  String get _categoryLabel {
    final tag = event?.tags?.isNotEmpty == true
        ? event!.tags!.first.name.trim()
        : '';
    return tag.isEmpty ? 'EVENT' : tag.toUpperCase();
  }

  String get _locationLabel {
    final address = event?.location.address.trim() ?? '';
    return address.isEmpty ? 'Location unavailable' : address;
  }

  String get _dateLabel {
    final start = event?.startTime.toLocal();
    return start == null
        ? 'Date unavailable'
        : DateFormat('EEE, d MMM').format(start);
  }

  String get _timeLabel {
    final currentEvent = event;
    if (currentEvent == null) return 'Time unavailable';
    final format = DateFormat('h:mm a');
    final start = currentEvent.startTime.toLocal();
    final end = currentEvent.endTime.toLocal();
    final nextDay = !_isSameDay(start, end) ? ' · next day' : '';
    return '${format.format(start)}–${format.format(end)}$nextDay';
  }

  int get _attachmentCount => event?.media?.length ?? 0;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _close(BuildContext context) => context.go(ExploreScreen.routePath);

  void _viewEvent(BuildContext context) {
    final currentEvent = event;
    if (currentEvent == null) {
      context.go(ExploreScreen.routePath);
      return;
    }
    context.go(
      EventDetailScreen.routePath.replaceAll(':id', currentEvent.id),
      extra: currentEvent,
    );
  }

  Future<void> _shareEvent(BuildContext context) async {
    final currentEvent = event;
    if (currentEvent == null) return;

    final message = buildEventShareMessage(
      name: currentEvent.name,
      startTime: currentEvent.startTime,
      address: currentEvent.location.address,
      link: AppConfig.shareLink('/event/${currentEvent.id}'),
    );
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: currentEvent.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'Unable to share this event right now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.appTypography;
    return Scaffold(
      backgroundColor: context.appPalette.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton.outlined(
                      key: const ValueKey('success_close_button'),
                      onPressed: () => _close(context),
                      icon: const Icon(LucideIcons.x),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            width: 116,
                            height: 116,
                            decoration: BoxDecoration(
                              color: context.appPalette.muted,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: context.appPalette.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.check,
                                size: AppIconSizes.xl,
                                color: context.appPalette.surface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'YOU’RE LIVE',
                            style: typography.overlineStrong.copyWith(
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your table is set.',
                            textAlign: TextAlign.center,
                            style: typography.heading2.copyWith(
                              fontFamily: typography.displayLG.fontFamily,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_title is ready to welcome guests. Share the invite or preview the event page.',
                            textAlign: TextAlign.center,
                            style: typography.bodyBase.copyWith(
                              color: context.appPalette.mutedForeground,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _buildEventSummary(context),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const ValueKey('success_share_button'),
                    onPressed: event == null
                        ? null
                        : () => _shareEvent(context),
                    icon: const Icon(LucideIcons.share2),
                    label: const Text('Share invite'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      backgroundColor: context.appPalette.primary,
                      foregroundColor: context.appPalette.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('success_view_event_button'),
                    onPressed: () => _viewEvent(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      foregroundColor: context.appPalette.primary,
                      side: BorderSide(color: context.appPalette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Text('View event page'),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'You can manage requests anytime from My Events.',
                    textAlign: TextAlign.center,
                    style: typography.bodyXS.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventSummary(BuildContext context) {
    final typography = context.appTypography;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appPalette.muted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.appPalette.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.utensils, size: AppIconSizes.m),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodyBaseSemi,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$_categoryLabel · ${event?.capacity == null ? 'Open capacity' : '${event!.capacity} spots'}',
                      style: typography.bodyXSStrong.copyWith(
                        color: context.appPalette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryItem(context, LucideIcons.calendar, _dateLabel),
              ),
              Expanded(
                child: _summaryItem(context, LucideIcons.clock, _timeLabel),
              ),
              Expanded(
                child: _summaryItem(
                  context,
                  LucideIcons.mapPin,
                  _locationLabel,
                ),
              ),
            ],
          ),
          if (_attachmentCount > 0) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.paperclip, size: AppIconSizes.s),
                const SizedBox(width: 7),
                Text('Supporting media', style: typography.bodyXSStrong),
                const Spacer(),
                Text(
                  '$_attachmentCount ${_attachmentCount == 1 ? 'attachment' : 'attachments'}',
                  style: typography.bodyXS.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(BuildContext context, IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: AppIconSizes.s, color: context.appPalette.mutedForeground),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.appTypography.bodyXSStrong,
        ),
      ],
    );
  }
}
