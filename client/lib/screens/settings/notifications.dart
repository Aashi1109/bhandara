import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/user.dart';
import '../../providers/user.dart';
import '../../theme/theme.dart';
import '../../widgets/button.dart';
import '../../widgets/header.dart';
import '../../widgets/snackbar.dart';
import '../settings.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  static const String routePath = '/settings/notifications';

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen> {
  bool _events = true;
  bool _chat = true;
  bool _replies = false;
  bool _reminders = true;
  bool _didHydrate = false;
  NotificationPreferences _initialPreferences = NotificationPreferences();

  void _hydrate(User? user) {
    if (_didHydrate || user == null) return;
    final prefs = user.meta?.notificationPreferences;
    if (prefs != null) {
      _events = prefs.events;
      _chat = prefs.chat;
      _replies = prefs.replies;
      _reminders = prefs.reminders;
      _initialPreferences = prefs;
    } else {
      _initialPreferences = NotificationPreferences(
        events: _events,
        chat: _chat,
        replies: _replies,
        reminders: _reminders,
      );
    }
    _didHydrate = true;
  }

  NotificationPreferences get _currentPreferences => NotificationPreferences(
    events: _events,
    chat: _chat,
    replies: _replies,
    reminders: _reminders,
  );

  bool get _isDirty {
    final current = _currentPreferences;
    return current.events != _initialPreferences.events ||
        current.chat != _initialPreferences.chat ||
        current.replies != _initialPreferences.replies ||
        current.reminders != _initialPreferences.reminders;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    _hydrate(user);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Notification Settings',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('ALERTS'),
                  const SizedBox(height: 16),
                  _notificationItem(
                    LucideIcons.calendar,
                    'New Food Events',
                    'ALERTS FOR EVENTS NEAR YOU',
                    _events,
                    (val) => setState(() => _events = val),
                  ),
                  const SizedBox(height: 12),
                  _notificationItem(
                    LucideIcons.messageCircle,
                    'Chat Messages',
                    'WHEN SOMEONE MESSAGES YOU',
                    _chat,
                    (val) => setState(() => _chat = val),
                  ),
                  const SizedBox(height: 12),
                  _notificationItem(
                    LucideIcons.messageSquare,
                    'Thread Replies',
                    'UPDATES ON YOUR COMMENTS',
                    _replies,
                    (val) => setState(() => _replies = val),
                  ),
                  const SizedBox(height: 12),
                  _notificationItem(
                    LucideIcons.bellRing,
                    'Event Reminders',
                    'BEFORE AN EVENT STARTS',
                    _reminders,
                    (val) => setState(() => _reminders = val),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: AppButton(
              size: AppButtonSize.xl,
              fullWidth: true,
              label: 'Save Preferences',
              loadable: true,
              onPressed: user == null || !_isDirty
                  ? null
                  : () async {
                      await ref
                          .read(userProfileProvider.notifier)
                          .updateUserData({
                            'meta': {
                              ...?user.meta?.toJson(),
                              'notificationPreferences': _currentPreferences
                                  .toJson(),
                            },
                          });
                      if (!mounted) return;
                      setState(() {
                        _initialPreferences = _currentPreferences;
                      });
                      AppSnackBar.success(
                        this.context,
                        'Notification preferences saved.',
                      );
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }

  Widget _notificationItem(
    IconData icon,
    String title,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        spacing: 16,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppIconSizes.defaultSize,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppColors.primary : AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
