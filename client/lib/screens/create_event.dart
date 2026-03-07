import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/input.dart';
import '../widgets/header.dart';
import '../services/event.dart';
import '../services/file.dart';
import 'explore.dart';
import 'success.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  static const String routePath = '/create';
  const CreateEventScreen({super.key});

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

    final now = DateTime.now();
    final startTime = now.add(const Duration(hours: 1));
    final endTime = now.add(const Duration(hours: 3));

    final response = await eventService.createEvent({
      'name': _titleController.text,
      'description': _descriptionController.text,
      'status': 'PUBLISHED',
      'visibility': 'PUBLIC',
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'coverId': _mediaId,
      'location': {
        'latitude': 34.0522,
        'longitude': -118.2437,
        'address': 'Downtown Los Angeles, CA',
      },
    });

    if (mounted) {
      setState(() => _isLoading = false);
      if (response.error != null) {
        setState(() => _error = response.error);
      } else {
        context.go(SuccessScreen.routePath);
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
                      size: 20,
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
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
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
                                                size: 48,
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
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.edit,
                                            size: 16,
                                            color: Colors.white,
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
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x33000000),
                                              blurRadius: 12,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          LucideIcons.uploadCloud,
                                          size: 24,
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
                                        size: 20,
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
                                child: Row(
                                  children: const [
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
                                      size: 20,
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
                                            size: 16,
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
                                            size: 16,
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
                        Row(
                          children: const [
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
                              size: 20,
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
                            size: 16,
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
