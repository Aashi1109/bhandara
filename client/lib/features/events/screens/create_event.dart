import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../chat/models/chat_attachment.dart';
import '../models/event.dart';
import '../../../shared/models/location_picker.dart';
import '../../profile/models/user.dart';
import '../../../shared/providers/tag.dart';
import '../../../shared/providers/user.dart';
import '../services/event.dart';
import '../../../shared/services/file.dart';
import '../../../shared/services/tag.dart';
import '../../../shared/theme/theme.dart';
import '../../../shared/utils/error.dart';
import '../utils/event_schedule.dart';
import '../../../shared/widgets/input.dart';
import '../../../shared/widgets/textarea.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/attachment_pill.dart';
import '../../../shared/widgets/skeleton.dart';
import '../widgets/media_preview.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../explore/screens/explore_screen.dart';
import '../../settings/screens/location.dart';
import '../../auth/screens/success.dart';

enum _MediaSourceAction { gallery, documents, cameraImage }

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({
    super.key,
    this.initialEvent,
    this.pickImage,
    this.pickVideo,
    this.pickMultipleMedia,
    this.uploadFile,
    this.createEventRequest,
    this.updateEventRequest,
    this.resolveTagIds,
    this.initialAttachments,
    this.initialSelectedAttachmentIndex = 0,
    this.initialLocation,
    this.initialStartAt,
    this.initialEndAt,
  });

  static const String routePath = '/create';
  static const int maxAttachments = 8;

  final Event? initialEvent;
  final Future<XFile?> Function(ImageSource source)? pickImage;
  final Future<XFile?> Function()? pickVideo;
  final Future<List<XFile>> Function(int limit)? pickMultipleMedia;
  final Future<String?> Function(XFile file)? uploadFile;
  final Future<void> Function(Map<String, dynamic> data)? createEventRequest;
  final Future<Event?> Function(String eventId, Map<String, dynamic> data)?
  updateEventRequest;
  final Future<List<String>> Function(User user)? resolveTagIds;
  final List<ChatAttachment>? initialAttachments;
  final int initialSelectedAttachmentIndex;
  final UserAddress? initialLocation;
  final DateTime? initialStartAt;
  final DateTime? initialEndAt;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _titleFieldKey = GlobalKey();
  final _descriptionFieldKey = GlobalKey();
  final _categoryFieldKey = GlobalKey();
  final _timingFieldKey = GlobalKey();
  final _locationFieldKey = GlobalKey();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _capacityController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('EEE, d MMM');
  final DateFormat _timeFormat = DateFormat('h:mm a');
  final List<ChatAttachment> _attachments = [];

  bool _isLoading = false;
  bool _didHydrateLocation = false;
  bool _didHydrateInitialEvent = false;
  String? _error;
  String? _titleError;
  String? _descriptionError;
  String? _locationError;
  String? _timingError;
  String? _categoryError;
  String? _capacityError;
  int _selectedAttachmentIndex = 0;
  UserAddress? _selectedLocation;
  LatLng? _locationPreviewTarget;
  double _locationPreviewZoom = 14;
  Tag? _selectedCategory;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _isPublic = true;
  bool _requiresApproval = false;
  bool _didSelectDate = false;
  bool _didSelectStartTime = false;
  bool _didSelectEndTime = false;

  ChatAttachment? get _coverAttachment =>
      _attachments.isEmpty ? null : _attachments.first;

  bool get _hasUploadInProgress => _attachments.any((item) => item.isUploading);
  bool get _hasFailedUploads => _attachments.any((item) => item.hasFailed);
  bool get _canSubmit =>
      !_isLoading && !_hasUploadInProgress && !_hasFailedUploads;
  bool get _isEditMode => widget.initialEvent != null;
  String get _screenTitle => _isEditMode ? 'Edit Event' : 'Create Event';
  String get _submitLabel => _isEditMode ? 'Update event' : 'Create event';
  TextStyle get _fieldTextStyle =>
      context.appTypography.bodyMD.copyWith(height: 1.2);
  TextStyle get _fieldPlaceholderStyle =>
      _fieldTextStyle.copyWith(color: context.appPalette.mutedForeground);

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

  Future<List<XFile>> _pickMultipleMediaFiles(int limit) {
    final picker = widget.pickMultipleMedia;
    if (picker != null) {
      return picker(limit);
    }
    return fileService.pickMultipleMedia(limit: limit);
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
    final hasInitialSchedule =
        widget.initialEvent != null || widget.initialStartAt != null;
    _didSelectDate = hasInitialSchedule;
    _didSelectStartTime = hasInitialSchedule;
    _didSelectEndTime =
        widget.initialEvent != null || widget.initialEndAt != null;
    _hydrateInitialEvent();
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _focusFirstInvalidField({
    required String? titleError,
    required String? descriptionError,
    required String? categoryError,
    required String? timingError,
    required String? locationError,
  }) {
    GlobalKey? targetKey;
    FocusNode? targetFocusNode;

    if (titleError != null) {
      targetKey = _titleFieldKey;
      targetFocusNode = _titleFocusNode;
    } else if (descriptionError != null) {
      targetKey = _descriptionFieldKey;
      targetFocusNode = _descriptionFocusNode;
    } else if (categoryError != null) {
      targetKey = _categoryFieldKey;
    } else if (timingError != null) {
      targetKey = _timingFieldKey;
    } else if (locationError != null) {
      targetKey = _locationFieldKey;
    }

    if (targetKey == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final targetContext = targetKey?.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      }

      if (!mounted) return;
      targetFocusNode?.requestFocus();
    });
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
    _selectedCategory = matched;
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
      backgroundColor: context.appPalette.transparent,
      builder: (context) => AppActionSheet(
        children: [
          AppActionSheetItem(
            icon: LucideIcons.galleryHorizontal,
            title: 'Gallery',
            subtitle:
                'Pick up to ${CreateEventScreen.maxAttachments} photos or videos',
            onTap: () => Navigator.pop(context, _MediaSourceAction.gallery),
          ),
          const SizedBox(height: 12),
          AppActionSheetItem(
            icon: LucideIcons.fileText,
            title: 'Choose Files',
            subtitle: 'Add PDF menus, flyers, or schedules',
            onTap: () => Navigator.pop(context, _MediaSourceAction.documents),
          ),
          const SizedBox(height: 12),
          AppActionSheetItem(
            icon: LucideIcons.camera,
            title: 'Take Photo',
            subtitle: 'Capture with your camera',
            onTap: () => Navigator.pop(context, _MediaSourceAction.cameraImage),
          ),
        ],
      ),
    );

    switch (action) {
      case _MediaSourceAction.gallery:
        await _addFromGallery();
        break;
      case _MediaSourceAction.documents:
        await _addDocuments();
        break;
      case _MediaSourceAction.cameraImage:
        await _addImage(ImageSource.camera);
        break;
      case null:
        break;
    }
  }

  Future<void> _addImage(ImageSource source) async {
    final file = await _pickImageFile(source);
    if (file == null) return;
    await _queueAttachment(file, isVideo: false);
  }

  Future<void> _handleCoverSelection() async {
    final file = await _pickImageFile(ImageSource.gallery);
    if (file == null) return;

    if (_attachments.isNotEmpty) {
      setState(() {
        _attachments.removeAt(0);
        _selectedAttachmentIndex = 0;
      });
    }
    await _queueAttachment(file, isVideo: false, insertAt: 0);
  }

  Future<void> _addDocuments() async {
    final remaining = CreateEventScreen.maxAttachments - _attachments.length;
    if (remaining <= 0) return;

    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    for (final picked in files.take(remaining)) {
      await _queueAttachment(picked.xFile, isVideo: false);
    }
  }

  Future<void> _addFromGallery() async {
    final remaining = CreateEventScreen.maxAttachments - _attachments.length;
    if (remaining <= 0) return;

    final files = await _pickMultipleMediaFiles(remaining);
    if (files.isEmpty) return;

    // Upload all picked files concurrently.
    await Future.wait(
      files.map((file) {
        final isVideo =
            file.mimeType?.startsWith('video/') == true ||
            file.name.toLowerCase().endsWith('.mp4') ||
            file.name.toLowerCase().endsWith('.mov') ||
            file.name.toLowerCase().endsWith('.avi') ||
            file.name.toLowerCase().endsWith('.mkv');
        return _queueAttachment(file, isVideo: isVideo);
      }),
    );
  }

  Future<void> _queueAttachment(
    XFile file, {
    required bool isVideo,
    int? insertAt,
  }) async {
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
      final targetIndex = insertAt?.clamp(0, _attachments.length);
      if (targetIndex == null) {
        _attachments.add(attachment);
        _selectedAttachmentIndex = _attachments.length - 1;
      } else {
        _attachments.insert(targetIndex, attachment);
        _selectedAttachmentIndex = targetIndex;
      }
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
    String? capacityError;

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

    final capacityText = _capacityController.text.trim();
    if (capacityText.isNotEmpty) {
      final capacity = int.tryParse(capacityText);
      if (capacity == null || capacity < 1) {
        capacityError = 'Enter a valid guest capacity.';
      }
    }

    if (!_didSelectDate || !_didSelectStartTime || !_didSelectEndTime) {
      timingError = 'Choose the event date, start time, and end time.';
    } else if (!_endAt.isAfter(_startAt)) {
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
      _capacityError = capacityError;
      _error =
          titleError != null ||
              descriptionError != null ||
              locationError != null ||
              timingError != null ||
              categoryError != null ||
              capacityError != null
          ? 'Fix the highlighted event details before continuing.'
          : null;
    });

    _focusFirstInvalidField(
      titleError: titleError,
      descriptionError: descriptionError,
      categoryError: categoryError,
      timingError: timingError,
      locationError: locationError,
    );

    return titleError == null &&
        descriptionError == null &&
        locationError == null &&
        timingError == null &&
        categoryError == null &&
        capacityError == null;
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
    if (index < 0 || index >= _attachments.length) return;
    if (_isDocumentAttachment(_attachments[index])) return;
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

  Future<void> _pickEventDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: _datePickerThemeBuilder,
    );
    if (pickedDate == null || !mounted) return;

    final duration = _endAt.difference(_startAt);
    final nextStart = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      _startAt.hour,
      _startAt.minute,
    );
    setState(() {
      _startAt = nextStart;
      _endAt = nextStart.add(duration);
      _didSelectDate = true;
      _timingError = null;
      _error = null;
    });
  }

  Future<void> _pickEventTime({required bool isStart}) async {
    final seed = isStart ? _startAt : _endAt;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      builder: _timePickerThemeBuilder,
    );
    if (pickedTime == null || !mounted) return;

    if (isStart) {
      final duration = _endAt.difference(_startAt);
      final nextStart = roundDateTimeToQuarterHour(
        DateTime(
          _startAt.year,
          _startAt.month,
          _startAt.day,
          pickedTime.hour,
          pickedTime.minute,
        ),
      );
      setState(() {
        _startAt = nextStart;
        _endAt = normalizeEventEndDateTime(
          start: nextStart,
          proposedEnd: nextStart.add(duration),
        );
        _didSelectStartTime = true;
        _timingError = null;
        _error = null;
      });
      return;
    }

    var proposedEnd = DateTime(
      _startAt.year,
      _startAt.month,
      _startAt.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!proposedEnd.isAfter(_startAt)) {
      proposedEnd = proposedEnd.add(const Duration(days: 1));
    }
    setState(() {
      _endAt = normalizeEventEndDateTime(
        start: _startAt,
        proposedEnd: proposedEnd,
      );
      _didSelectEndTime = true;
      _timingError = null;
      _error = null;
    });
  }

  Widget _datePickerThemeBuilder(BuildContext context, Widget? child) {
    final colorScheme = ColorScheme.light(
      primary: context.appPalette.primary,
      onPrimary: context.appPalette.surface,
      surface: context.appPalette.surface,
      onSurface: context.appPalette.primary,
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colorScheme,
        dialogTheme: DialogThemeData(backgroundColor: context.appPalette.surface),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Widget _timePickerThemeBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: context.appPalette.primary,
          onPrimary: context.appPalette.surface,
          surface: context.appPalette.surface,
          onSurface: context.appPalette.primary,
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: context.appPalette.surface,
          dayPeriodBorderSide: BorderSide(color: context.appPalette.border),
          dayPeriodColor: context.appPalette.muted,
          dayPeriodTextColor: context.appPalette.primary,
          dialHandColor: context.appPalette.primary,
          dialBackgroundColor: context.appPalette.muted,
          hourMinuteColor: context.appPalette.muted,
          hourMinuteTextColor: context.appPalette.primary,
          entryModeIconColor: context.appPalette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> _handleCreate({bool saveAsDraft = false}) async {
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
      final capacity = int.tryParse(_capacityController.text.trim());

      final payload = {
        'name': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': widget.initialEvent?.type ?? 'custom',
        if (saveAsDraft) 'status': 'draft',
        'createdBy': widget.initialEvent?.createdBy ?? user.id,
        'startTime': _startAt.toUtc().toIso8601String(),
        'endTime': _endAt.toUtc().toIso8601String(),
        if (uploadedMediaIds.isNotEmpty) 'media': uploadedMediaIds,
        if (capacity != null && capacity > 0) 'capacity': capacity,
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
        if (saveAsDraft) {
          context.go(ExploreScreen.routePath);
        } else {
          context.go(SuccessScreen.routePath, extra: createdEvent);
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      if (saveAsDraft) {
        context.go(ExploreScreen.routePath);
      } else {
        context.go(SuccessScreen.routePath);
      }
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
      backgroundColor: context.appPalette.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildCreateHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntro(),
                        if (_error != null) ...[
                          const SizedBox(height: 20),
                          _buildValidationBanner(),
                        ],
                        const SizedBox(height: 24),
                        _buildCoverUpload(),
                        const SizedBox(height: 26),
                        _buildSupportingMedia(),
                        const SizedBox(height: 28),
                        _buildDetailsSection(
                          categoriesAsync.value ?? const [],
                          isLoadingCategories: categoriesAsync.isLoading,
                        ),
                        const SizedBox(height: 28),
                        _buildScheduleSection(),
                        const SizedBox(height: 28),
                        _buildGuestAccessSection(),
                        const SizedBox(height: 28),
                        _buildFormActions(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) _buildPublishingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCreateHeader() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appPalette.surface,
        border: Border(bottom: BorderSide(color: context.appPalette.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            key: const ValueKey('create_event_close_button'),
            onTap: () => _isEditMode
                ? context.pop()
                : context.go(ExploreScreen.routePath),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appPalette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: context.appPalette.border),
              ),
              child: Icon(
                LucideIcons.x,
                size: AppIconSizes.defaultSize,
                color: context.appPalette.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _screenTitle,
              textAlign: TextAlign.center,
              style: context.appTypography.heading3Heavy,
            ),
          ),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appPalette.muted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _isEditMode ? 'Editing' : 'Draft',
              style: context.appTypography.labelXSStrong.copyWith(
                color: context.appPalette.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEditMode ? 'REFINE THE GATHERING' : 'HOST SOMETHING MEMORABLE',
          style: context.appTypography.overlineStrong.copyWith(
            color: context.appPalette.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isEditMode ? 'Make the details sing.' : 'Bring people together.',
          style: context.appTypography.heading2.copyWith(
            fontFamily: context.appTypography.displayLG.fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share the essentials now. You can fine-tune everything before publishing.',
          style: context.appTypography.bodyBase.copyWith(
            color: context.appPalette.mutedForeground,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildValidationBanner() {
    final errorCount = [
      _titleError,
      _descriptionError,
      _categoryError,
      _timingError,
      _locationError,
      _capacityError,
    ].whereType<String>().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appPalette.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.alertCircle,
              size: AppIconSizes.m,
              color: context.appPalette.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$errorCount ${errorCount == 1 ? 'thing needs' : 'things need'} your attention',
                  style: context.appTypography.bodySMExtraBold,
                ),
                const SizedBox(height: 2),
                Text(
                  _error!,
                  style: context.appTypography.bodyXS.copyWith(
                    color: context.appPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverUpload() {
    final cover = _coverAttachment;
    return GestureDetector(
      key: const ValueKey('create_event_hero_preview'),
      onTap: _handleCoverSelection,
      child: Container(
        width: double.infinity,
        height: 178,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.appPalette.muted,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.appPalette.border),
        ),
        child: cover == null
            ? _buildEmptyCoverState()
            : Stack(
                fit: StackFit.expand,
                children: [
                  _buildCoverImage(cover),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.appPalette.surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: context.appPalette.primary.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.camera, size: AppIconSizes.s),
                          const SizedBox(width: 7),
                          Text(
                            'Replace cover',
                            style: context.appTypography.labelSMStrong,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyCoverState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: context.appPalette.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.imagePlus,
            size: AppIconSizes.l,
            color: context.appPalette.primary,
          ),
        ),
        const SizedBox(height: 10),
        Text('Add an event cover', style: context.appTypography.titleSM),
        const SizedBox(height: 4),
        Text(
          'JPG or PNG · 16:9 works best',
          style: context.appTypography.bodyXS.copyWith(
            color: context.appPalette.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverImage(ChatAttachment cover) {
    if (cover.isUploading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cover.hasFailed || cover.isVideo) {
      return Container(
        color: context.appPalette.muted,
        alignment: Alignment.center,
        child: Icon(
          cover.hasFailed ? LucideIcons.alertCircle : LucideIcons.video,
          color: cover.hasFailed ? context.appPalette.error : context.appPalette.primary,
          size: AppIconSizes.hero,
        ),
      );
    }

    final source = cover.url?.isNotEmpty == true ? cover.url! : cover.localPath;
    Widget fallback() => Container(
      color: context.appPalette.muted,
      alignment: Alignment.center,
      child: const Icon(LucideIcons.image, size: AppIconSizes.hero),
    );
    if (source.startsWith('http') || kIsWeb) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
    return Image.file(
      File(source),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback(),
    );
  }

  Widget _buildSupportingMedia() {
    final supporting = _attachments.asMap().entries.skip(1).toList();
    if (supporting.isEmpty) return _buildEmptySupportingMedia();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supporting media',
                    style: context.appTypography.titleLGStrong,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Help guests picture the experience',
                    style: context.appTypography.bodyXS.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${_attachments.length}/${CreateEventScreen.maxAttachments}',
              style: context.appTypography.labelXSStrong.copyWith(
                color: context.appPalette.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          key: const ValueKey('create_event_attachment_list'),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...supporting.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildAttachmentChip(entry.key, entry.value),
                ),
              ),
              GestureDetector(
                onTap: _handleMediaSelection,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.appPalette.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: context.appPalette.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.plus, size: AppIconSizes.s),
                      const SizedBox(width: 6),
                      Text(
                        'Add more',
                        style: context.appTypography.labelSMStrong,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySupportingMedia() {
    return GestureDetector(
      key: const ValueKey('create_event_supporting_media'),
      onTap: _handleMediaSelection,
      child: Container(
        width: double.infinity,
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.appPalette.muted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appPalette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.appPalette.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.imagePlus,
                size: AppIconSizes.m,
                color: context.appPalette.surface,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bring the moment to life',
                    style: context.appTypography.bodyBaseSemi.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add photos, videos or PDFs · Optional',
                    style: context.appTypography.bodyXS.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormActions() {
    return Container(
      padding: const EdgeInsets.only(top: 22),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.appPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey('create_event_save_draft_button'),
              onPressed: _canSubmit
                  ? () => _handleCreate(saveAsDraft: true)
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                foregroundColor: context.appPalette.primary,
                side: BorderSide(color: context.appPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Save draft'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const ValueKey('create_event_submit_button'),
              onPressed: _canSubmit ? _handleCreate : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: context.appPalette.primary,
                foregroundColor: context.appPalette.surface,
                disabledBackgroundColor: context.appPalette.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_submitLabel),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, size: AppIconSizes.m),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: context.appPalette.surface.withValues(alpha: 0.88),
        child: Center(
          child: Container(
            width: 342,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.appPalette.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: context.appPalette.border),
              boxShadow: [
                BoxShadow(
                  color: context.appPalette.primary.withValues(alpha: 0.14),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: context.appPalette.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.send,
                    color: context.appPalette.surface,
                    size: AppIconSizes.l,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Creating your event…',
                  style: context.appTypography.titleLGStrong,
                ),
                const SizedBox(height: 8),
                Text(
                  'Uploading media and preparing your guest page. Keep this screen open for a moment.',
                  textAlign: TextAlign.center,
                  style: context.appTypography.bodySM.copyWith(
                    color: context.appPalette.mutedForeground,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(
                  color: context.appPalette.primary,
                  backgroundColor: context.appPalette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = _selectedLocation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppInputLabel(label: 'Location'),
        const SizedBox(height: 8),
        KeyedSubtree(
          key: _locationFieldKey,
          child: AppInput(
            key: const ValueKey('create_event_location_card'),
            value: location?.label ?? '',
            placeholder: 'Add a venue or address',
            readOnly: true,
            onTap: _openLocationPicker,
            error: _locationError,
            textStyle: _fieldTextStyle,
            placeholderStyle: _fieldPlaceholderStyle,
            icon: const Icon(LucideIcons.mapPin, size: 18),
            rightElement: const Icon(LucideIcons.chevronRight, size: 18),
            height: 54,
            borderRadius: 16,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            elementSpacing: 10,
            trailingSpacing: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(
    List<Tag> categories, {
    bool isLoadingCategories = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'The essentials',
                style: context.appTypography.titleLGStrong,
              ),
            ),
            Text(
              'Required',
              style: context.appTypography.bodySM.copyWith(
                color: context.appPalette.mutedForeground,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _titleFieldKey,
          child: AppInput(
            label: 'Event name',
            textStyle: _fieldTextStyle,
            placeholderStyle: _fieldPlaceholderStyle,
            placeholder: 'e.g. Sunday supper club',
            controller: _titleController,
            focusNode: _titleFocusNode,
            error: _titleError,
            icon: const Icon(LucideIcons.sparkles, size: 18),
            height: 54,
            borderRadius: 16,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            elementSpacing: 10,
            textFieldContentPadding: EdgeInsets.zero,
            onChanged: _handleTitleChanged,
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _descriptionFieldKey,
          child: AppTextArea(
            label: 'What’s it about?',
            placeholder: 'Tell guests what to expect…',
            controller: _descriptionController,
            focusNode: _descriptionFocusNode,
            height: 88,
            minLines: 1,
            maxLines: 3,
            error: _descriptionError,
            onChanged: _handleDescriptionChanged,
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _categoryFieldKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppInputLabel(label: 'Category'),
              const SizedBox(height: 8),
              if (isLoadingCategories)
                const AppSkeletonLine(height: 38)
              else
                SingleChildScrollView(
                  key: const ValueKey('create_event_category_list'),
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: categories.map((tag) {
                      final selected = _selectedCategory?.id == tag.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          key: ValueKey('create_event_category_${tag.id}'),
                          onTap: () {
                            setState(() {
                              _selectedCategory = tag;
                              _categoryError = null;
                              _error = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: selected
                                  ? context.appPalette.muted
                                  : context.appPalette.surface,
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: selected
                                    ? context.appPalette.primary
                                    : context.appPalette.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcon(tag.name),
                                  size: 14,
                                  color: selected
                                      ? context.appPalette.primary
                                      : context.appPalette.mutedForeground,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  tag.name,
                                  style: context.appTypography.bodyXS.copyWith(
                                    color: selected
                                        ? context.appPalette.primary
                                        : context.appPalette.mutedForeground,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              if (_categoryError != null) ...[
                const SizedBox(height: 8),
                AppInputError(message: _categoryError!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('food') || normalized.contains('dining')) {
      return LucideIcons.utensils;
    }
    if (normalized.contains('learn') || normalized.contains('workshop')) {
      return LucideIcons.lightbulb;
    }
    if (normalized.contains('music')) return LucideIcons.music;
    if (normalized.contains('wellness') || normalized.contains('fitness')) {
      return LucideIcons.heartPulse;
    }
    return LucideIcons.users;
  }

  Widget _buildScheduleSection() {
    return KeyedSubtree(
      key: _timingFieldKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('When & where', style: context.appTypography.titleLGStrong),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimeField(
                  key: const ValueKey('create_event_start_field'),
                  label: 'Starts',
                  value: _startAt,
                  onTap: () => _pickEventTime(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeField(
                  key: const ValueKey('create_event_end_field'),
                  label: 'Ends',
                  value: _endAt,
                  nextDay: !_isSameDay(_startAt, _endAt),
                  onTap: () => _pickEventTime(isStart: false),
                ),
              ),
            ],
          ),
          if (_timingError != null) ...[
            const SizedBox(height: 8),
            AppInputError(message: _timingError!),
          ],
          const SizedBox(height: 16),
          _buildLocationCard(),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return AppInput(
      key: const ValueKey('create_event_date_field'),
      label: 'Date',
      value: _didSelectDate ? _dateFormat.format(_startAt) : '',
      placeholder: 'Choose date',
      textStyle: _fieldTextStyle,
      placeholderStyle: _fieldPlaceholderStyle,
      readOnly: true,
      onTap: _pickEventDate,
      icon: const Icon(LucideIcons.calendar, size: 18),
      height: 54,
      borderRadius: 16,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      elementSpacing: 10,
    );
  }

  Widget _buildTimeField({
    required Key key,
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    bool nextDay = false,
  }) {
    return AppInput(
      key: key,
      label: label,
      value: (label == 'Starts' ? _didSelectStartTime : _didSelectEndTime)
          ? '${_timeFormat.format(value)}${nextDay ? ' +1' : ''}'
          : '',
      placeholder: 'Choose time',
      textStyle: _fieldTextStyle,
      placeholderStyle: _fieldPlaceholderStyle,
      readOnly: true,
      onTap: onTap,
      error: _timingError,
      showErrorText: false,
      icon: const Icon(LucideIcons.watch, size: 18),
      height: 54,
      borderRadius: 16,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      elementSpacing: 10,
    );
  }

  Widget _buildGuestAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Guests & access', style: context.appTypography.titleLGStrong),
        const SizedBox(height: 16),
        AppInput(
          label: 'Guest capacity',
          textStyle: _fieldTextStyle,
          placeholderStyle: _fieldPlaceholderStyle,
          placeholder: 'No limit',
          controller: _capacityController,
          keyboardType: TextInputType.number,
          error: _capacityError,
          onChanged: (_) {
            if (_capacityError == null && _error == null) return;
            setState(() {
              _capacityError = null;
              _error = null;
            });
          },
          icon: const Icon(LucideIcons.users, size: 18),
          height: 54,
          borderRadius: 16,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          elementSpacing: 10,
          textFieldContentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        const AppInputLabel(label: 'Who can see this?'),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.appPalette.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(child: _buildVisibilityOption(public: true)),
              const SizedBox(width: 4),
              Expanded(child: _buildVisibilityOption(public: false)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Approve requests',
                    style: context.appTypography.bodySMExtraBold,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Review guests before they’re added',
                    style: context.appTypography.bodyXS.copyWith(
                      color: context.appPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _requiresApproval,
              activeTrackColor: context.appPalette.primary,
              activeThumbColor: context.appPalette.surface,
              onChanged: (value) => setState(() => _requiresApproval = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVisibilityOption({required bool public}) {
    final selected = _isPublic == public;
    return GestureDetector(
      key: ValueKey(public ? 'create_event_public' : 'create_event_private'),
      onTap: () => setState(() => _isPublic = public),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? context.appPalette.surface : context.appPalette.muted,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              public ? LucideIcons.globe2 : LucideIcons.lock,
              size: 15,
              color: selected ? context.appPalette.primary : context.appPalette.mutedForeground,
            ),
            const SizedBox(width: 7),
            Text(
              public ? 'Public' : 'Private',
              style: context.appTypography.labelSMStrong.copyWith(
                color: selected ? context.appPalette.primary : context.appPalette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildAttachmentChip(int index, ChatAttachment file) {
    return AttachmentPill(
      key: ValueKey('create_event_attachment_$index'),
      file: file,
      onTap: _isDocumentAttachment(file)
          ? null
          : () => _openMediaPreview(index),
      onRetry: () => _retryAttachment(file),
      onRemove: () => _removeAttachment(file),
    );
  }

  bool _isDocumentAttachment(ChatAttachment attachment) {
    final name = attachment.name.toLowerCase();
    return name.endsWith('.pdf');
  }

  void _hydrateInitialEvent() {
    final initialEvent = widget.initialEvent;
    if (_didHydrateInitialEvent || initialEvent == null) return;

    _titleController.text = initialEvent.name;
    _descriptionController.text = initialEvent.description ?? '';
    _capacityController.text = initialEvent.capacity?.toString() ?? '';
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
