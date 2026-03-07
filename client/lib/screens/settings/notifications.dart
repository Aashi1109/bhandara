import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/button.dart';
import '../settings.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  static const String routePath = '/settings/notifications';
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsAlerts = false;
  bool _eventReminders = true;
  bool _marketingUpdates = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Notifications',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('SYSTEM NOTIFICATIONS'),
                  const SizedBox(height: 12),
                  _notificationContainer([
                    _toggleItem(
                      LucideIcons.bell,
                      'Push Notifications',
                      'Alerts on your device',
                      _pushNotifications,
                      (val) => setState(() => _pushNotifications = val),
                      showBorder: true,
                    ),
                    _toggleItem(
                      LucideIcons.mail,
                      'Email Notifications',
                      'Daily digests and updates',
                      _emailNotifications,
                      (val) => setState(() => _emailNotifications = val),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  _sectionLabel('EVENT UPDATES'),
                  const SizedBox(height: 12),
                  _notificationContainer([
                    _toggleItem(
                      LucideIcons.calendar,
                      'Event Reminders',
                      'Alerts for upcoming events',
                      _eventReminders,
                      (val) => setState(() => _eventReminders = val),
                      showBorder: true,
                    ),
                    _toggleItem(
                      LucideIcons.messageSquare,
                      'SMS Alerts',
                      'Critical updates via text',
                      _smsAlerts,
                      (val) => setState(() => _smsAlerts = val),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  _sectionLabel('PROMOTIONAL'),
                  const SizedBox(height: 12),
                  _notificationContainer([
                    _toggleItem(
                      LucideIcons.star,
                      'Marketing Updates',
                      'New features and offers',
                      _marketingUpdates,
                      (val) => setState(() => _marketingUpdates = val),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: AppButton(
              size: AppButtonSize.xl,
              fullWidth: true,
              label: 'Save Preferences',
              onPressed: () {},
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

  Widget _notificationContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggleItem(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool showBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.mutedForeground),
          ),
          const SizedBox(width: 12),
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
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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
