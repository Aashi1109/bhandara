import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/theme.dart';
import '../../widgets/header.dart';
import '../../widgets/button.dart';
import '../../widgets/input.dart';
import '../settings.dart';

class Cuisine {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  Cuisine({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class CuisineInterestsScreen extends StatefulWidget {
  static const String routePath = '/settings/cuisines';
  const CuisineInterestsScreen({super.key});

  @override
  State<CuisineInterestsScreen> createState() => _CuisineInterestsScreenState();
}

class _CuisineInterestsScreenState extends State<CuisineInterestsScreen> {
  final List<Cuisine> cuisines = [
    Cuisine(
      id: 'street',
      name: 'Street Food',
      description: 'FOOD TRUCKS, STALLS, QUICK BITES',
      icon: LucideIcons.utensils,
    ),
    Cuisine(
      id: 'bakery',
      name: 'Bakery',
      description: 'PASTRIES, BREAD, DESSERTS',
      icon: LucideIcons.apple,
    ),
    Cuisine(
      id: 'vegan',
      name: 'Vegan',
      description: 'PLANT-BASED, CRUELTY-FREE',
      icon: LucideIcons.leaf,
    ),
    Cuisine(
      id: 'italian',
      name: 'Italian',
      description: 'PASTA, PIZZA, MEDITERRANEAN',
      icon: LucideIcons.pizza,
    ),
    Cuisine(
      id: 'seafood',
      name: 'Seafood',
      description: 'FISH, SHELLFISH, OCEANIC',
      icon: LucideIcons.soup,
    ),
    Cuisine(
      id: 'coffee',
      name: 'Coffee & Tea',
      description: 'CAFES, ROASTERIES, BEVERAGES',
      icon: LucideIcons.coffee,
    ),
  ];

  final Set<String> _selectedIds = {'street', 'bakery'};

  void _toggleCuisine(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Cuisine Interests',
            onBack: () => context.go(SettingsScreen.routePath),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Select the types of cuisine you\'re interested in to get personalized event recommendations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const AppInput(
                    placeholder: 'Search cuisines...',
                    icon: Icon(LucideIcons.search),
                    height: 56,
                    borderRadius: 16,
                  ),
                  const SizedBox(height: 24),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cuisines.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final cuisine = cuisines[index];
                      final isSelected = _selectedIds.contains(cuisine.id);

                      return GestureDetector(
                        onTap: () => _toggleCuisine(cuisine.id),
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
                                  cuisine.icon,
                                  size: 20,
                                  color: isSelected
                                      ? AppColors.surface
                                      : AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cuisine.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cuisine.description,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                        color: AppColors.mutedForeground,
                                      ),
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
                                        size: 14,
                                        color: AppColors.surface,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: AppButton(
              size: AppButtonSize.xl,
              fullWidth: true,
              label: 'Save Changes',
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
