import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../models/chat_attachment.dart';
import '../models/event.dart';
import '../models/location_picker.dart';
import '../models/user.dart';
import '../providers/tag.dart';
import '../providers/user.dart';
import '../services/event.dart';
import '../services/file.dart';
import '../services/location_permission.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/map_provider_type.dart';
import '../services/tag.dart';
import '../theme/theme.dart';
import '../utils/error.dart';
import '../utils/event_schedule.dart';
import '../widgets/header.dart';
import '../widgets/input.dart';
import '../widgets/textarea.dart';
import '../widgets/attachment_pill.dart';
import '../widgets/map_view.dart';
import '../widgets/media_preview.dart';
import '../widgets/snackbar.dart';
import 'explore/explore_screen.dart';
import 'settings/location.dart';
import 'success.dart';

enum _MediaSourceAction { galleryImage, cameraImage, galleryVideo }

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({
    super.key,
    this.initialEvent,
    this.pickImage,
    this.pickVideo,
    this.uploadFile,
    this.createEventRequest,
    this.updateEventRequest,
    this.resolveTagIds,
    this.currentLocationResolver,
    this.initialAttachments,
    this.initialSelectedAttachmentIndex = 0,
    this.initialLocation,
    this.initialStartAt,
    this.initialEndAt,
  });

  static const String routePath = '/create';
  static const int maxAttachments = 5;

  final Event? initialEvent;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  final Future<XFile?> Function()? pickVideo;
  final Future<String?> Function(XFile file)? uploadFile;
  final Future<void> Function(Map<String, dynamic> data)? createEventRequest;
  final Future<Event?> Function(String eventId, Map<String, dynamic> data)?
  updateEventRequest;
  final Future<List<String>> Function(User user)? resolveTagIds;
  final Future<UserAddress?> Function()? currentLocationResolver;
  final List<ChatAttachment>? initialAttachments;
  final int initialSelectedAttachmentIndex;
  final UserAddress? initialLocation;
  final DateTime? initialStartAt;
  final DateTime? initialEndAt;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('EEE, d MMM');
  final DateFormat _timeFormat = DateFormat('h:mm a');
  final List<ChatAttachment> _attachments = [];
  final MapManager _mapManager = MapManager(type: MapProviderType.google);

  bool _isLoading = false;
  bool _didHydrateLocation = false;
  bool _didHydrateInitialEvent = false;
  double _launchDragProgress = 0;
  String? _error;
  String? _titleError;
  String? _descriptionError;
  String? _locationError;
  String? _timingError;
  String? _categoryError;
  int _selectedAttachmentIndex = 0;
  UserAddress? _selectedLocation;
  LatLng? _locationPreviewTarget;
  double _locationPreviewZoom = 14;
  Tag? _selectedCategory;
  late DateTime _startAt;
  late DateTime _endAt;

  Set<Factory<OneSequenceGestureRecognizer>> get _mapGestureRecognizers => {
    Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
    Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
  };

  bool get _hasUploadInProgress => _attachments.any((item) => item.isUploading);
  bool get _hasFailedUploads => _attachments.any((item) => item.hasFailed);
  bool get _canSubmit =>
      !_isLoading && !_hasUploadInProgress && !_hasFailedUploads;
  bool get _canDragLaunch => _canSubmit && !_isLoading;
  bool get _isEditMode => widget.initialEvent != null;
  String get _screenTitle => _isEditMode ? 'Edit Event' : 'Create Event';
  String get _submitLabel => _isEditMode ? 'Update Event' : 'Launch Event';

  Future<List<String>> _resolveDefaultTagIds(User user) async {
    final interestIds = user.meta?.interests ?? const <String>[];
    if (interestIds.isNotEmpty) return interestIds;

    final rootTags = await tagService.getTags(rootOnly: true);
    if (rootTags.isNotEmpty) {
      return [rootTags.first.id];
    }

    throw Exception('At least one category tag is required to create an event');
  }

  Future<String?> _uploadAttachmentFile(XFile file) {
    final uploader = widget.uploadFile;
    if (uploader != null) {
      return uploader(file);
    }
    return fileService.uploadFile(file);
  }

  Future<XFile?> _pickImageFile(ImageSource source) {
    final picker = widget.pickImage;
    if (picker != null) {
      return picker(source);
    }
    return fileService.pickImage(source: source);
  }

  Future<XFile?> _pickVideoFile() {
    final picker = widget.pickVideo;
    if (picker != null) {
      return picker();
    }
    return fileService.pickVideo();
  }

  @override
  void initState() {
    super.initState();
    _attachments.addAll(
      widget.initialAttachments ??
          _seedAttachmentsFromEvent(widget.initialEvent),
    );
    _selectedAttachmentIndex = widget.initialSelectedAttachmentIndex;
    _selectedLocation = widget.initialLocation;
    if (widget.initialLocation?.latitude != null &&
        widget.initialLocation?.longitude != null) {
      _locationPreviewTarget = LatLng(
        widget.initialLocation!.latitude!,
        widget.initialLocation!.longitude!,
      );
    }
    _didHydrateLocation = widget.initialLocation != null;
    _startAt =
        widget.initialStartAt ??
        roundDateTimeToQuarterHour(
          DateTime.now().add(const Duration(hours: 1)),
        );
    _endAt = widget.initialEndAt ?? _startAt.add(const Duration(hours: 2));
    _hydrateInitialEvent();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleTitleChanged(String value) {
    if (_titleError == null && _error == null) return;
    setState(() {
      _titleError = null;
      _error = null;
    });
  }

  void _handleDescriptionChanged(String value) {
    if (_descriptionError == null && _error == null) return;
    setState(() {
      _descriptionError = null;
      _error = null;
    });
  }

  void _hydrateInitialCategory(User? user, List<Tag> rootTags) {
    if (_selectedCategory != null || rootTags.isEmpty) return;
    final initialTagId = widget.initialEvent?.tags?.isNotEmpty == true
        ? widget.initialEvent!.tags!.first.id
        : null;
    if (initialTagId != null) {
      final matchedInitial = rootTags.cast<Tag?>().firstWhere(
        (tag) => tag?.id == initialTagId,
        orElse: () => null,
      );
      if (matchedInitial != null) {
        _selectedCategory = matchedInitial;
        return;
      }
    }
    final interests = user?.meta?.interests ?? const <String>[];
    final preferredId = interests.isNotEmpty ? interests.first : null;
    final matched = preferredId == null
        ? null
        : rootTags.cast<Tag?>().firstWhere(
            (tag) => tag?.id == preferredId,
            orElse: () => null,
          );
    _selectedCategory = matched ?? rootTags.first;
  }

  Future<void> _handleMediaSelection() async {
    if (_attachments.length >= CreateEventScreen.maxAttachments) {
      AppSnackBar.info(
        context,
        'You can upload up to ${CreateEventScreen.maxAttachments} files.',
      );
      return;
    }

    final action = await showModalBottomSheet<_MediaSourceAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              _mediaActionTile(
                icon: LucideIcons.image,
                title: 'Pick Image from Gallery',
                onTap: () =>
                    Navigator.pop(context, _MediaSourceAction.galleryImage),
              ),
              _mediaActionTile(
                icon: LucideIcons.camera,
                title: 'Take Photo',
                onTap: () =>
                    Navigator.pop(context, _MediaSourceAction.cameraImage),
              ),
              _mediaActionTile(
                icon: LucideIcons.video,
                title: 'Upload Video (Max 10MB)',
                onTap: () =>
                    Navigator.pop(context, _MediaSourceAction.galleryVideo),
              ),
            ],
          ),
        ),
      ),
    );

    switch (action) {
      case _MediaSourceAction.galleryImage:
        await _addImage(ImageSource.gallery);
        break;
      case _MediaSourceAction.cameraImage:
        await _addImage(ImageSource.camera);
        break;
      case _MediaSourceAction.galleryVideo:
        await _addVideo();
        break;
      case null:
        break;
    }
  }

  Widget _mediaActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: context.appTypography.titleXS.copyWith(color: AppColors.primary),
      ),
      onTap: onTap,
    );
  }

  Future<void> _addImage(ImageSource source) async {
    final file = await _pickImageFile(source);
    if (file == null) return;
    await _queueAttachment(file, isVideo: false);
  }

  Future<void> _addVideo() async {
    final file = await _pickVideoFile();
    if (file == null) return;
    await _queueAttachment(file, isVideo: true);
  }

  Future<void> _queueAttachment(XFile file, {required bool isVideo}) async {
    if (_attachments.length >= CreateEventScreen.maxAttachments) return;

    final sizeBytes = await file.length();
    final attachment = ChatAttachment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: file.name,
      localPath: file.path,
      sizeBytes: sizeBytes,
      isVideo: isVideo,
      isUploading: true,
    );

    setState(() {
      _error = null;
      _attachments.add(attachment);
      _selectedAttachmentIndex = _attachments.length - 1;
    });

    await _uploadAttachment(attachment);
  }

  Future<void> _uploadAttachment(ChatAttachment attachment) async {
    try {
      final mediaId = await _uploadAttachmentFile(
        XFile(attachment.localPath, name: attachment.name),
      );
      if (!mounted) return;

      setState(() {
        final index = _attachments.indexWhere(
          (item) => item.id == attachment.id,
        );
        if (index == -1) return;
        _attachments[index] = _attachments[index].copyWith(
          mediaId: mediaId,
          isUploading: false,
          hasFailed: false,
        );
      });
    } catch (e) {
      if (!mounted) return;
      final message = extractExceptionMessage(e);

      setState(() {
        final index = _attachments.indexWhere(
          (item) => item.id == attachment.id,
        );
        if (index == -1) return;
        _attachments[index] = _attachments[index].copyWith(
          isUploading: false,
          hasFailed: true,
        );
        _error = null;
      });
      AppSnackBar.error(context, message);
    }
  }

  void _retryAttachment(ChatAttachment attachment) {
    setState(() {
      final index = _attachments.indexWhere((item) => item.id == attachment.id);
      if (index == -1) return;
      _attachments[index] = _attachments[index].copyWith(
        isUploading: true,
        hasFailed: false,
      );
      _error = null;
    });
    _uploadAttachment(attachment);
  }

  void _removeAttachment(ChatAttachment attachment) {
    setState(() {
      final index = _attachments.indexWhere((item) => item.id == attachment.id);
      if (index == -1) return;
      _attachments.removeAt(index);
      if (_attachments.isEmpty) {
        _selectedAttachmentIndex = 0;
      } else if (_selectedAttachmentIndex >= _attachments.length) {
        _selectedAttachmentIndex = _attachments.length - 1;
      } else if (_selectedAttachmentIndex > index) {
        _selectedAttachmentIndex -= 1;
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    try {
      final resolved = widget.currentLocationResolver != null
          ? await widget.currentLocationResolver!()
          : await _resolveCurrentLocation();
      if (!mounted || resolved == null) return;
      setState(() {
        _selectedLocation = resolved;
        _didHydrateLocation = true;
        if (resolved.latitude != null && resolved.longitude != null) {
          _locationPreviewTarget = LatLng(
            resolved.latitude!,
            resolved.longitude!,
          );
          _locationPreviewZoom = 14;
        }
        _locationError = null;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Unable to get current location.');
    }
  }

  Future<UserAddress?> _resolveCurrentLocation() async {
    var status = await LocationPermissionService.currentStatus();
    if (!LocationPermissionService.hasAccess(status)) {
      status = await LocationPermissionService.requestOnStartup();
    }
    if (!LocationPermissionService.hasAccess(status)) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    final resolved = await _mapManager.getAddressFromCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (resolved == null) {
      return UserAddress(
        label:
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    return UserAddress(
      label: resolved.formattedAddress,
      latitude: resolved.latitude,
      longitude: resolved.longitude,
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await context.push<LocationPickerResult>(
      LocationSettingsScreen.routePath,
      extra: LocationScreenArgs(
        mode: LocationSelectionMode.picker,
        initialLocation: _selectedLocation,
        initialCameraLatitude: _locationPreviewTarget?.latitude,
        initialCameraLongitude: _locationPreviewTarget?.longitude,
        initialZoom: _locationPreviewZoom,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedLocation = result.location;
        _didHydrateLocation = true;
        _locationPreviewTarget = LatLng(
          result.cameraLatitude,
          result.cameraLongitude,
        );
        _locationPreviewZoom = result.zoom;
        _locationError = null;
        _error = null;
      });
    }
  }

  bool _validateForm() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    String? titleError;
    String? descriptionError;
    String? locationError;
    String? timingError;
    String? categoryError;

    if (title.isEmpty) {
      titleError = 'Please enter an event title.';
    } else if (title.length < 3) {
      titleError = 'Title must be at least 3 characters.';
    } else if (title.length > 80) {
      titleError = 'Title must be 80 characters or less.';
    }

    if (description.isEmpty) {
      descriptionError = 'Please add a short event description.';
    } else if (description.length < 10) {
      descriptionError = 'About Event must be at least 10 characters.';
    } else if (description.length > 500) {
      descriptionError = 'About Event must be 500 characters or less.';
    }

    if (_selectedLocation == null || _selectedLocation!.label.trim().isEmpty) {
      locationError = 'Select an event location.';
    }

    if (_selectedCategory == null) {
      categoryError = 'Select an event category.';
    }

    if (!_endAt.isAfter(_startAt)) {
      timingError = 'End time must be after the start time.';
    } else if (!_endAt.isAfter(DateTime.now())) {
      timingError = 'Event end time must be in the future.';
    } else if (_endAt.isAfter(_startAt.add(const Duration(days: 7)))) {
      timingError = 'Event duration cannot exceed 7 days.';
    }

    setState(() {
      _titleError = titleError;
      _descriptionError = descriptionError;
      _locationError = locationError;
      _timingError = timingError;
      _categoryError = categoryError;
      _error =
          titleError != null ||
              descriptionError != null ||
              locationError != null ||
              timingError != null ||
              categoryError != null
          ? 'Fix the highlighted event details before continuing.'
          : null;
    });

    return titleError == null &&
        descriptionError == null &&
        locationError == null &&
        timingError == null &&
        categoryError == null;
  }

  Future<void> _openCategoryPicker(List<Tag> categories) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              ...categories.map((tag) {
                final isSelected = _selectedCategory?.id == tag.id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    tag.name,
                    style: context.appTypography.titleXS.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          LucideIcons.check,
                          size: AppIconSizes.defaultSize,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, tag.id),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selectedId == null || !mounted) return;
    final nextCategory = categories.firstWhere((tag) => tag.id == selectedId);
    setState(() {
      _selectedCategory = nextCategory;
      _categoryError = null;
      _error = null;
    });
  }

  Future<ChatAttachment?> _resolveAttachmentPreview(int index) async {
    if (index < 0 || index >= _attachments.length) return null;

    final attachment = _attachments[index];
    if (attachment.url != null && attachment.url!.isNotEmpty) {
      return attachment;
    }
    if (attachment.mediaId == null || attachment.mediaId!.isEmpty) {
      return attachment;
    }

    final media = await fileService.getMediaById(attachment.mediaId!);
    final previewUrl = (media?['publicUrl'] ?? media?['url']) as String?;
    if (!mounted || previewUrl == null || previewUrl.isEmpty) {
      return attachment;
    }

    final updated = attachment.copyWith(url: previewUrl);
    setState(() {
      _attachments[index] = updated;
    });
    return updated;
  }

  Future<void> _openMediaPreview(int index) async {
    if (_attachments.isEmpty) return;
    final selected = await _resolveAttachmentPreview(index);
    if (selected == null || !mounted) return;
    if (selected.isUploading || selected.hasFailed) return;
    if (selected.url == null || selected.url!.isEmpty) return;

    final uploadedAttachments = _attachments
        .where((file) => file.url != null && file.url!.isNotEmpty)
        .toList();
    final initialIndex = uploadedAttachments.indexWhere(
      (file) => file.id == selected.id,
    );
    if (initialIndex == -1) return;

    final items = uploadedAttachments.map((file) {
      return MediaItem(
        id: file.mediaId ?? file.id,
        url: file.url!,
        thumbnail: file.url!,
        type: file.isVideo ? 'video' : 'image',
        name: file.name,
        sizeBytes: file.sizeBytes,
      );
    }).toList();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Media preview',
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => AppMediaPreview(
        items: items,
        initialIndex: initialIndex,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final seed = isStart ? _startAt : _endAt;
    final firstDate = isStart
        ? DateTime.now().subtract(const Duration(days: 7))
        : DateTime(_startAt.year, _startAt.month, _startAt.day);
    final lastDate = isStart
        ? DateTime.now().add(const Duration(days: 30))
        : _startAt.add(const Duration(days: 7));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: _datePickerThemeBuilder,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      builder: _timePickerThemeBuilder,
    );
    if (pickedTime == null || !mounted) return;

    final pickedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (isStart) {
      final normalizedStart = roundDateTimeToQuarterHour(pickedDateTime);
      var normalizedEnd = normalizeEventEndDateTime(
        start: normalizedStart,
        proposedEnd: _endAt,
      );
      if (normalizedEnd == normalizedStart.add(const Duration(minutes: 30))) {
        normalizedEnd = normalizedStart.add(const Duration(hours: 2));
      }

      setState(() {
        _startAt = normalizedStart;
        _endAt = normalizedEnd;
        _timingError = null;
        _error = null;
      });
      return;
    }

    final normalizedEnd = normalizeEventEndDateTime(
      start: _startAt,
      proposedEnd: pickedDateTime,
    );
    if (!pickedDateTime.isAfter(_startAt)) {
      AppSnackBar.info(
        context,
        'End time was adjusted to stay after the start time.',
      );
    }
    if (pickedDateTime.isAfter(_startAt.add(const Duration(days: 7)))) {
      AppSnackBar.info(
        context,
        'End time was limited to 7 days after the start time.',
      );
    }

    setState(() {
      _endAt = normalizedEnd;
      _timingError = null;
      _error = null;
    });
  }

  Widget _datePickerThemeBuilder(BuildContext context, Widget? child) {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.primary,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colorScheme,
        dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Widget _timePickerThemeBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.surface,
          surface: AppColors.surface,
          onSurface: AppColors.primary,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: AppColors.surface,
          dayPeriodBorderSide: const BorderSide(color: AppColors.border),
          dayPeriodColor: AppColors.muted,
          dayPeriodTextColor: AppColors.primary,
          dialHandColor: AppColors.primary,
          dialBackgroundColor: AppColors.muted,
          hourMinuteColor: AppColors.muted,
          hourMinuteTextColor: AppColors.primary,
          entryModeIconColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> _handleCreate() async {
    if (!_validateForm()) return;
    if (!_canSubmit) {
      setState(() {
        _error = _hasFailedUploads
            ? 'Resolve failed uploads before creating the event.'
            : 'Wait for uploads to finish before creating the event.';
      });
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

      final tagIds = _selectedCategory != null
          ? <String>[_selectedCategory!.id]
          : await (widget.resolveTagIds ?? _resolveDefaultTagIds)(user);
      final selectedLocation =
          _selectedLocation ??
          user.address ??
          UserAddress(label: 'Location not set');
      final uploadedMediaIds = _attachments
          .map((item) => item.mediaId)
          .whereType<String>()
          .toList();

      final payload = {
        'name': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': widget.initialEvent?.type ?? 'custom',
        'createdBy': widget.initialEvent?.createdBy ?? user.id,
        'timings': {
          'start': _startAt.toUtc().toIso8601String(),
          'end': _endAt.toUtc().toIso8601String(),
        },
        if (uploadedMediaIds.isNotEmpty) 'media': uploadedMediaIds,
        'tags': tagIds,
        'location': {
          'address': selectedLocation.label,
          'coordinates': {
            if (selectedLocation.latitude != null)
              'latitude': selectedLocation.latitude,
            if (selectedLocation.longitude != null)
              'longitude': selectedLocation.longitude,
          },
        },
      };

      if (_isEditMode) {
        final updatedEvent = widget.updateEventRequest != null
            ? await widget.updateEventRequest!(widget.initialEvent!.id, payload)
            : await eventService.updateEvent(widget.initialEvent!.id, payload);
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).pop(updatedEvent ?? widget.initialEvent);
        return;
      }

      if (widget.createEventRequest != null) {
        await widget.createEventRequest!(payload);
      } else {
        final createdEvent = await eventService.createEvent(payload);
        if (!mounted) return;
        setState(() => _isLoading = false);
        context.go(SuccessScreen.routePath, extra: createdEvent);
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(SuccessScreen.routePath);
    } catch (e) {
      if (!mounted) return;
      final message = extractExceptionMessage(e);
      setState(() {
        _isLoading = false;
        _error = null;
      });
      AppSnackBar.error(context, message);
    }
  }

  void _handleLaunchDragUpdate(DragUpdateDetails details, double maxTravel) {
    if (!_canDragLaunch || maxTravel <= 0) return;

    setState(() {
      _launchDragProgress =
          (_launchDragProgress + (details.delta.dx / maxTravel)).clamp(
            0.0,
            1.0,
          );
    });
  }

  Future<void> _handleLaunchDragEnd() async {
    final shouldLaunch = _launchDragProgress >= 0.92 && _canDragLaunch;
    if (!mounted) return;

    if (shouldLaunch) {
      setState(() {
        _launchDragProgress = 1;
      });
      await _handleCreate();
    }

    if (!mounted) return;
    setState(() {
      _launchDragProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final categoriesAsync = ref.watch(tagsProvider(rootOnly: true));
    final user = userAsync.value;
    if (!_didHydrateLocation && user?.address != null) {
      _selectedLocation = user!.address;
      if (user.address?.latitude != null && user.address?.longitude != null) {
        _locationPreviewTarget = LatLng(
          user.address!.latitude!,
          user.address!.longitude!,
        );
      }
      _didHydrateLocation = true;
    }
    categoriesAsync.whenData((tags) => _hydrateInitialCategory(user, tags));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                AppHeader(
                  title: _screenTitle,
                  onBack: () => _isEditMode
                      ? context.pop()
                      : context.go(ExploreScreen.routePath),
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
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailsSection(categoriesAsync.value ?? const []),
                        const SizedBox(height: 24),
                        _buildLocationCard(),
                        const SizedBox(height: 24),
                        _buildHeroPreview(),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildAttachmentPills(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildLaunchSlider(),
          ),
        ],
      ),
    );
  }

  Widget _buildLaunchSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 10.0;
        const knobSize = 52.0;
        final maxTravel =
            constraints.maxWidth - (horizontalPadding * 2) - knobSize;
        final startLeft = maxTravel / 2;
        final endLeft = maxTravel;
        final knobLeft =
            horizontalPadding +
            (lerpDouble(startLeft, endLeft, _launchDragProgress) ?? startLeft);

        return GestureDetector(
          key: const ValueKey('create_event_launch_slider'),
          onHorizontalDragUpdate: (details) =>
              _handleLaunchDragUpdate(details, maxTravel / 2),
          onHorizontalDragEnd: (_) => _handleLaunchDragEnd(),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: _canDragLaunch
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.surface,
                      strokeWidth: 2,
                    ),
                  )
                else
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: _launchDragProgress,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 12,
                        children: [
                          Text(
                            _submitLabel,
                            style: context.appTypography.titleMD.copyWith(
                              color: AppColors.surface,
                            ),
                          ),
                          const Icon(
                            LucideIcons.arrowRight,
                            size: AppIconSizes.defaultSize,
                            color: AppColors.surface,
                          ),
                        ],
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOut,
                  left: knobLeft,
                  top: 6,
                  child: Container(
                    width: knobSize,
                    height: knobSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.arrowRight,
                      size: AppIconSizes.defaultSize,
                      color:
                          (_canDragLaunch
                                  ? AppColors.surface
                                  : AppColors.mutedForeground)
                              .withValues(alpha: 1 - _launchDragProgress),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroPreview() {
    return GestureDetector(
      key: const ValueKey('create_event_hero_preview'),
      onTap: _handleMediaSelection,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: _handleMediaSelection,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
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
                  const SizedBox(height: 10),
                  Text(
                    'Upload Event Media',
                    style: context.appTypography.labelMD.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ADD PHOTOS OR VIDEO FOR THE EVENT',
                    style: context.appTypography.overline,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPills() {
    return SingleChildScrollView(
      key: const ValueKey('create_event_attachment_list'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _attachments.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(
              right: entry.key == _attachments.length - 1 ? 0 : 8,
            ),
            child: _buildAttachmentChip(entry.key, entry.value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = _selectedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('Location')),
            GestureDetector(
              key: const ValueKey('create_event_current_location_action'),
              onTap: _useCurrentLocation,
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.locateFixed,
                    size: AppIconSizes.s,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Use Current',
                    style: context.appTypography.labelSM.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_locationError != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              _locationError!,
              style: context.appTypography.labelSM.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
        Container(
          height: 160,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: _buildMiniMapPreview(location)),
              IgnorePointer(
                child: Center(
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
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          location?.label.isNotEmpty == true
                              ? location!.label.toUpperCase()
                              : 'TAP TO PINPOINT',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTypography.overline.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  key: const ValueKey('create_event_location_card'),
                  onTap: _openLocationPicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      LucideIcons.expand,
                      size: AppIconSizes.defaultSize,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(List<Tag> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Event Details'),
        const SizedBox(height: 8),
        AppInput(
          placeholder: 'Event Title (e.g. Midnight Pizza)',
          controller: _titleController,
          error: _titleError,
          onChanged: _handleTitleChanged,
        ),
        const SizedBox(height: 16),
        _sectionLabel('About Event'),
        const SizedBox(height: 8),
        AppTextArea(
          placeholder:
              'What is happening, who is it for, and what should people know?',
          controller: _descriptionController,
          minLines: 5,
          maxLines: 5,
          error: _descriptionError,
          onChanged: _handleDescriptionChanged,
        ),
        const SizedBox(height: 16),
        GestureDetector(
          key: const ValueKey('create_event_category_field'),
          onTap: categories.isEmpty
              ? null
              : () => _openCategoryPicker(categories),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _categoryError != null
                    ? AppColors.error
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedCategory?.name ??
                        (categories.isEmpty
                            ? 'Loading categories...'
                            : 'Select Category'),
                    style: context.appTypography.labelMD.copyWith(
                      color: _selectedCategory != null
                          ? AppColors.primary
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                const Icon(
                  LucideIcons.chevronDown,
                  size: AppIconSizes.defaultSize,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
        if (_categoryError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _categoryError!,
              style: context.appTypography.labelSM.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildDateTimeField(
                key: const ValueKey('create_event_start_field'),
                label: 'Starts',
                value: _startAt,
                onTap: () => _pickDateTime(isStart: true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateTimeField(
                key: const ValueKey('create_event_end_field'),
                label: 'Ends',
                value: _endAt,
                onTap: () => _pickDateTime(isStart: false),
              ),
            ),
          ],
        ),
        if (_timingError != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _timingError!,
              style: context.appTypography.labelSM.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeField({
    required Key key,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        GestureDetector(
          key: key,
          onTap: onTap,
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendarClock, size: AppIconSizes.m),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateFormat.format(value),
                        style: context.appTypography.captionMD.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeFormat.format(value),
                        style: context.appTypography.bodySM.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMapPreview(UserAddress? location) {
    final target =
        _locationPreviewTarget ??
        LatLng(location?.latitude ?? 21.1702, location?.longitude ?? 79.6527);
    return Stack(
      fit: StackFit.expand,
      children: [
        AppMapView(
          manager: _mapManager,
          initialCameraPosition: CameraPosition(
            target: target,
            zoom: _locationPreviewZoom,
          ),
          markers: const <Marker>{},
          gestureRecognizers: _mapGestureRecognizers,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surface.withValues(alpha: 0.06),
                AppColors.primary.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentChip(int index, ChatAttachment file) {
    return AttachmentPill(
      key: ValueKey('create_event_attachment_$index'),
      file: file,
      onTap: () => _openMediaPreview(index),
      onRetry: () => _retryAttachment(file),
      onRemove: () => _removeAttachment(file),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text.toUpperCase(), style: context.appTypography.overline);
  }

  void _hydrateInitialEvent() {
    final initialEvent = widget.initialEvent;
    if (_didHydrateInitialEvent || initialEvent == null) return;

    _titleController.text = initialEvent.name;
    _descriptionController.text = initialEvent.description ?? '';
    _startAt = initialEvent.startTime;
    _endAt = initialEvent.endTime;
    _selectedLocation = UserAddress(
      label: initialEvent.location.address,
      latitude: initialEvent.location.latitude,
      longitude: initialEvent.location.longitude,
    );
    if (initialEvent.location.latitude != null &&
        initialEvent.location.longitude != null) {
      _locationPreviewTarget = LatLng(
        initialEvent.location.latitude!,
        initialEvent.location.longitude!,
      );
    }
    if (initialEvent.tags?.isNotEmpty == true) {
      _selectedCategory = initialEvent.tags!.first;
    }
    _didHydrateLocation = true;
    _didHydrateInitialEvent = true;
  }

  List<ChatAttachment> _seedAttachmentsFromEvent(Event? event) {
    final media = event?.media ?? const <Media>[];
    return media
        .map(
          (item) => ChatAttachment(
            id: item.id,
            mediaId: item.id,
            name: item.url.split('/').last,
            url: item.url,
            localPath: item.url,
            sizeBytes: 0,
            isVideo: item.type.toLowerCase().contains('video'),
          ),
        )
        .toList();
  }
}
