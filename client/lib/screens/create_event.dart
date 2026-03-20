import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../providers/user.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/input.dart';
import '../widgets/header.dart';
import '../services/event.dart';
import '../services/file.dart';
import '../services/tag.dart';
import '../utils/error.dart';
import 'explore.dart';
import 'success.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  static const String routePath = '/create';

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  String? _mediaId;
  String? _localMediaPath;
  bool _isLocalVideo = false;

  DateTime _resolveTime({required String raw, required DateTime fallback}) {
    final input = raw.trim();
    if (input.isEmpty) return fallback;

    final match = RegExp(
      r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])$',
    ).firstMatch(input);
    if (match == null) return fallback;

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0');
    final period = (match.group(3) ?? '').toUpperCase();
    if (hour == null || minute == null || hour < 1 || hour > 12) {
      return fallback;
    }

    var normalizedHour = hour % 12;
    if (period == 'PM') normalizedHour += 12;

    final now = DateTime.now();
    var resolved = DateTime(
      now.year,
      now.month,
      now.day,
      normalizedHour,
      minute,
    );

    if (resolved.isBefore(now)) {
      resolved = resolved.add(const Duration(days: 1));
    }

    return resolved;
  }

  Future<List<String>> _resolveTagIds(User user) async {
    final interestIds = user.meta?.interests ?? const <String>[];
    if (interestIds.isNotEmpty) return interestIds;

    final rootTags = await tagService.getTags(rootOnly: true);
    if (rootTags.isNotEmpty) {
      return [rootTags.first.id];
    }

    throw Exception('At least one category tag is required to create an event');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _handleMediaSelection() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.image, color: AppColors.primary),
              title: const Text('Pick Image from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: AppColors.primary),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.video, color: AppColors.primary),
              title: const Text('Upload Video (Max 10MB)'),
              onTap: () async {
                Navigator.pop(context);
                await _pickVideo();
              },
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await fileService.pickImage(source: source);
      if (file != null) {
        setState(() {
          _localMediaPath = file.path;
          _isLocalVideo = false;
          _isUploading = true;
          _error = null;
        });

        final id = await fileService.uploadFile(file);
        if (mounted) {
          setState(() {
            _mediaId = id;
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await fileService.pickVideo();
      if (file != null) {
        setState(() {
          _localMediaPath = file.path;
          _isLocalVideo = true;
          _isUploading = true;
          _error = null;
        });

        final id = await fileService.uploadFile(file);
        if (mounted) {
          setState(() {
            _mediaId = id;
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _handleCreate() async {
    if (_titleController.text.isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await ref.read(userProfileProvider.future);
      if (user == null) {
        throw Exception('You need to be signed in to create an event');
      }

      final now = DateTime.now();
      final startTime = _resolveTime(
        raw: _startTimeController.text,
        fallback: now.add(const Duration(hours: 1)),
      );
      var endTime = _resolveTime(
        raw: _endTimeController.text,
        fallback: startTime.add(const Duration(hours: 2)),
      );

      if (!endTime.isAfter(startTime)) {
        endTime = startTime.add(const Duration(hours: 2));
      }

      final address = user.address ?? UserAddress(label: 'Location not set');
      final tagIds = await _resolveTagIds(user);

      await eventService.createEvent({
        'name': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': 'draft',
        'type': 'custom',
        'createdBy': user.id,
        'timings': {
          'start': startTime.toIso8601String(),
          'end': endTime.toIso8601String(),
        },
        if (_mediaId != null) 'media': [_mediaId],
        'tags': tagIds,
        'location': {
          'address': address.label,
          'coordinates': {
            if (address.latitude != null) 'latitude': address.latitude,
            if (address.longitude != null) 'longitude': address.longitude,
          },
        },
      });

      if (mounted) {
        setState(() => _isLoading = false);
        context.go(SuccessScreen.routePath);
      }
    } catch (e) {
      if (mounted) {
        final message = extractExceptionMessage(e);
        setState(() {
          _isLoading = false;
          _error = message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                AppHeader(
                  title: 'Create Event',
                  onBack: () => context.go(ExploreScreen.routePath),
                  rightElement: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      LucideIcons.moreVertical,
                      size: AppIconSizes.defaultSize,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 0.66,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      180,
                    ), // Extra bottom padding for sticky footer
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Image/Video Upload Section
                        GestureDetector(
                          onTap: _isUploading ? null : _handleMediaSelection,
                          child: Container(
                            width: double.infinity,
                            height: 192,
                            decoration: BoxDecoration(
                              color: AppColors.muted,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: AppColors.border,
                                width: 2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  )
                                : _localMediaPath != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _isLocalVideo
                                          ? const Center(
                                              child: Icon(
                                                LucideIcons.playCircle,
                                                size: AppIconSizes.hero,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : Image.file(
                                              File(_localMediaPath!),
                                              fit: BoxFit.cover,
                                            ),
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.54,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.edit,
                                            size: AppIconSizes.m,
                                            color: AppColors.surface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          LucideIcons.uploadCloud,
                                          size: AppIconSizes.l,
                                          color: AppColors.surface,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Upload Event Cover',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'TAP FOR IMAGE OR VIDEO (MAX 10MB)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        _sectionLabel('Location'),
                        const SizedBox(height: 12),
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _DotPatternPainter(),
                                ),
                              ),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.mapPin,
                                        size: AppIconSizes.defaultSize,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(50),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: const Text(
                                        'TAP TO PINPOINT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Form Details
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Event Details'),
                              const SizedBox(height: 8),
                              AppInput(
                                placeholder:
                                    'Event Title (e.g. Midnight Pizza)',
                                height: 56,
                                controller: _titleController,
                              ),
                              const SizedBox(height: 16),

                              // Category dropdown
                              Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.muted,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Select Category',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      LucideIcons.chevronDown,
                                      size: AppIconSizes.defaultSize,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Time inputs
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _sectionLabel('Starts'),
                                        const SizedBox(height: 8),
                                        AppInput(
                                          placeholder: '08:00 AM',
                                          height: 56,
                                          controller: _startTimeController,
                                          rightElement: const Icon(
                                            LucideIcons.clock,
                                            size: AppIconSizes.m,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _sectionLabel('Ends'),
                                        const SizedBox(height: 8),
                                        AppInput(
                                          placeholder: '10:00 AM',
                                          height: 56,
                                          controller: _endTimeController,
                                          rightElement: const Icon(
                                            LucideIcons.clock,
                                            size: AppIconSizes.m,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Notes
                              _sectionLabel('Notes'),
                              const SizedBox(height: 8),
                              AppInput(
                                placeholder:
                                    'Dietary info, access codes, etc...',
                                height: 128,
                                controller: _descriptionController,
                                maxLines: 5,
                                backgroundColor: AppColors.muted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sticky Footer
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: AppButton(
              size: AppButtonSize.xl,
              fullWidth: true,
              onPressed: _isLoading ? null : _handleCreate,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.surface,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text(
                              'Launch Event',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.surface,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(
                              LucideIcons.rocket,
                              size: AppIconSizes.defaultSize,
                              color: AppColors.surface,
                            ),
                          ],
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.arrowRight,
                            size: AppIconSizes.m,
                            color: AppColors.surface,
                          ),
                        ),
                      ],
                    ),
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
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
