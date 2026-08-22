import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../events/models/event.dart';
import '../../../shared/providers/tag.dart';
import '../../../shared/providers/user.dart';
import '../../../shared/providers/user_settings.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/widgets/app_search_bar.dart';
import '../../../shared/widgets/header.dart';
import '../../../shared/widgets/settings_action_footer.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/snackbar.dart';
import './settings.dart';

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
    final settings = ref.read(userSettingsProvider).value;
    if (_didHydrate || settings == null) return;
    _selectedIds.addAll(settings.interests);
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

  Widget _buildLoadingState() {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: 6,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              AppSkeleton(width: 44, height: 44, shape: BoxShape.circle),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonLine(width: 120, height: 14),
                    SizedBox(height: 8),
                    AppSkeletonLine(width: 90, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 16),
              AppSkeleton(width: 24, height: 24, shape: BoxShape.circle),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _hydrateFromUser();
    final user = ref.watch(userProfileProvider).value;
    ref.watch(userSettingsProvider);
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
                  AppSearchBar(
                    placeholder: 'Search cuisines...',
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: tagsAsync.when(
                      loading: _buildLoadingState,
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
                    final current = _selectedIds.toSet();

                    await ref
                        .read(userSettingsProvider.notifier)
                        .updateSettings(user.id, {
                          'interests': current.toList(),
                        });
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
