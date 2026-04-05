import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/event.dart';
import '../../providers/tag.dart';
import '../../providers/user.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/input.dart';
import '../../widgets/settings_action_footer.dart';
import '../../widgets/snackbar.dart';
import '../settings.dart';

class CuisineInterestsScreen extends ConsumerStatefulWidget {
  const CuisineInterestsScreen({super.key});

  static const String routePath = '/settings/cuisines';

  @override
  ConsumerState<CuisineInterestsScreen> createState() =>
      _CuisineInterestsScreenState();
}

class _CuisineInterestsScreenState
    extends ConsumerState<CuisineInterestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = <String>{};
  Set<String> _initialSelectedIds = <String>{};
  bool _didHydrate = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleCuisine(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _hydrateFromUser() {
    final user = ref.read(userProfileProvider).value;
    if (_didHydrate || user == null) return;
    _selectedIds.addAll(user.meta?.interests ?? const <String>[]);
    _initialSelectedIds = {..._selectedIds};
    _didHydrate = true;
  }

  bool get _isDirty {
    if (_selectedIds.length != _initialSelectedIds.length) return true;
    return !_selectedIds.containsAll(_initialSelectedIds);
  }

  IconData _iconForTag(Tag tag) {
    final value = (tag.value ?? tag.name).toLowerCase();
    if (value.contains('vegan')) return LucideIcons.leaf;
    if (value.contains('street')) return LucideIcons.utensils;
    if (value.contains('bakery')) return LucideIcons.cake;
    if (value.contains('coffee') || value.contains('tea')) {
      return LucideIcons.coffee;
    }
    if (value.contains('seafood') || value.contains('fish')) {
      return LucideIcons.fish;
    }
    if (value.contains('pizza') || value.contains('italian')) {
      return LucideIcons.pizza;
    }
    return LucideIcons.utensils;
  }

  String _descriptionForTag(Tag tag) {
    final source = tag.value ?? tag.name;
    return source.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    _hydrateFromUser();
    final user = ref.watch(userProfileProvider).value;
    final tagsAsync = ref.watch(tagsProvider(rootOnly: true));
    final query = _searchController.text.trim().toLowerCase();
    final typography = context.appTypography;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Cuisine Interests',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select the types of cuisine you\'re interested in to get personalized event recommendations.',
                      textAlign: TextAlign.center,
                      style: typography.bodyMD,
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppInput(
                    placeholder: 'Search cuisines...',
                    icon: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(LucideIcons.search),
                    ),
                    borderRadius: 16,
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: tagsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                      error: (error, _) => Center(
                        child: Text(
                          error.toString(),
                          style: typography.bodyMD.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                      data: (tags) {
                        final filtered = query.isEmpty
                            ? tags
                            : tags.where((tag) {
                                final haystack =
                                    '${tag.name} ${tag.value ?? ''}'
                                        .toLowerCase();
                                return haystack.contains(query);
                              }).toList();

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final tag = filtered[index];
                            final isSelected = _selectedIds.contains(tag.id);

                            return GestureDetector(
                              onTap: () => _toggleCuisine(tag.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.muted,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _iconForTag(tag),
                                        size: AppIconSizes.defaultSize,
                                        color: isSelected
                                            ? AppColors.surface
                                            : AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tag.name,
                                            style: typography.labelMD,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _descriptionForTag(tag),
                                            style: typography.captionSM,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.muted,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.border,
                                          width: 2,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              LucideIcons.check,
                                              size: AppIconSizes.s,
                                              color: AppColors.surface,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsActionFooter(
            label: 'Save Changes',
            loadable: true,
            onPressed: user == null || !_isDirty
                ? null
                : () async {
                    final previous = user.meta?.interests.toSet() ?? <String>{};
                    final current = _selectedIds.toSet();

                    await ref.read(userProfileProvider.notifier).updateUserData(
                      {
                        'interests': {
                          'added': current.difference(previous).toList(),
                          'deleted': previous.difference(current).toList(),
                        },
                      },
                    );
                    if (!mounted) return;
                    setState(() {
                      _initialSelectedIds = {...current};
                    });
                    AppSnackBar.success(
                      this.context,
                      'Cuisine interests saved.',
                    );
                  },
          ),
        ],
      ),
    );
  }
}
