import 'dart:ui';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config.dart';
import '../../../shared/constants/socket_events.dart';
import '../../chat/models/chat.dart';
import '../models/engagement.dart';
import '../models/event.dart';
import '../../saved/models/save.dart';
import '../../../shared/providers/user.dart';
import '../services/engagement.dart';
import '../services/event.dart';
import '../../../shared/services/maps/map_manager.dart';
import '../../../shared/services/maps/map_marker_painter.dart';
import '../../../shared/services/maps/map_provider_type.dart';
import '../../../shared/utils/maps.dart';
import '../../saved/services/save.dart';
import '../../../shared/services/socket.dart';
import '../../../shared/theme/theme.dart';
import '../utils/event_share.dart';
import '../utils/event_status.dart';
import '../../../shared/utils/error.dart';
import '../../../shared/widgets/avatar.dart';
import '../../../shared/widgets/button.dart';
import '../widgets/review_editor_sheet.dart';
import '../widgets/event_ratings_preview.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/snackbar.dart';
import './create_event.dart';
import './event_attendees.dart';
import './event_ratings.dart';
import '../../explore/screens/explore_screen.dart';

enum _EventDetailActionKey { share, save, edit }

class _EventDetailAction {
  const _EventDetailAction({
    required this.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.enabled = true,
    this.loading = false,
    this.tooltip,
  });

  final _EventDetailActionKey key;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool loading;
  final String? tooltip;
}

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.id, this.initialEvent});

  static const String routePath = '/event/:id';

  final String id;
  final Event? initialEvent;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  static const Duration _heroAnimationDuration = Duration(milliseconds: 260);
  static const String _defaultHeroImageSeed = 'event-detail-fallback';
  static const String _defaultEventName = 'Event';
  static const String _defaultEventStatus = 'draft';
  static const String _defaultLocationLabel = 'Location unavailable';
  static const String _defaultPrimaryTag = 'Food';
  static const double _mobileLocationMapHeight = 176;
  static const double _webLocationMapHeight = 240;
  static const double _locationMapMarkerSize = 36;
  static const double _locationMapMarkerAnchorOffset = 0.41;

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Event? _event;
  EngagementSummary? _engagementSummary;
  List<EventReview> _eventReviews = const [];
  bool _isLoading = true;
  bool _isHydratingFullEvent = false;
  bool _isLoadingEngagement = false;
  bool _isJoining = false;
  bool _isSubmittingReview = false;
  bool _isLoadingSaveState = false;
  bool _isTogglingSave = false;
  bool _hasJoined = false;
  bool _isHeroExpanded = true;
  int _heroMediaIndex = 0;
  final MapManager _mapManager = MapManager(type: MapProviderType.google);
  SavedEntitySummary? _saveSummary;

  @override
  void initState() {
    super.initState();
    _event = widget.initialEvent;
    _isLoading = widget.initialEvent == null;
    _isHydratingFullEvent = widget.initialEvent != null;
    if ((widget.initialEvent?.media?.length ?? 0) > 2) {
      _isHeroExpanded = false;
    }

    if (widget.initialEvent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadEvent(showBlockingLoader: false);
      });
      _checkIfJoined();
      _listenToSocketMessages();
      return;
    }

    _loadEvent();
  }

  Future<void> _loadEvent({bool showBlockingLoader = true}) async {
    setState(() {
      if (showBlockingLoader) {
        _isLoading = true;
      } else {
        _isHydratingFullEvent = true;
      }
    });

    try {
      final event = await eventService.getEvent(widget.id);
      if (!mounted) return;

      setState(() {
        _event = _event?.merge(event) ?? event;
        _isLoading = false;
        _isHydratingFullEvent = false;
        _heroMediaIndex = _clampMediaIndexFor(_event);
        // Collapse the hero header when the event has more than 2 media items
        // so carousel navigation gets more visual space.
        if ((_event?.media?.length ?? 0) > 2) {
          _isHeroExpanded = false;
        }
      });

      _checkIfJoined();
      unawaited(_loadSaveState());
      await _loadEngagement(silent: !showBlockingLoader);

      if (showBlockingLoader) {
        _listenToSocketMessages();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isHydratingFullEvent = false;
      });
    }
  }

  bool get _isOwner {
    final currentUser = ref.read(userProfileProvider).value;
    return currentUser != null && currentUser.id == _event?.createdBy;
  }

  bool get _isExpired {
    final event = _event;
    if (event == null) return false;
    final status = resolveEventStatus(event);
    return status == EventStatusValue.completed ||
        status == EventStatusValue.cancelled;
  }

  Future<void> _loadEngagement({bool silent = true}) async {
    if (!mounted) return;
    setState(() => _isLoadingEngagement = !silent);
    try {
      final summary = await engagementService.getEntityEngagement(
        'events',
        widget.id,
      );
      if (!mounted) return;
      _applyEngagementSummary(summary);
      unawaited(_loadReviewPreview());
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingEngagement = false);
    }
  }

  Future<void> _loadReviewPreview() async {
    try {
      final reviews = await engagementService.getEntityRatings(
        'events',
        widget.id,
      );
      if (!mounted) return;
      setState(() => _eventReviews = reviews);
    } catch (_) {
      // The rating summary remains useful when review details are unavailable.
    }
  }

  Future<void> _loadSaveState() async {
    final currentUser = ref.read(userProfileProvider).value;
    if (currentUser == null || _event == null || _isOwner) {
      if (mounted) {
        setState(() {
          _saveSummary = null;
          _isLoadingSaveState = false;
        });
      }
      return;
    }

    setState(() => _isLoadingSaveState = true);
    try {
      final summary = await saveService.getSaveState('event', widget.id);
      if (!mounted) return;
      setState(() {
        _saveSummary = summary;
        _isLoadingSaveState = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingSaveState = false);
    }
  }

  void _checkIfJoined() {
    final currentUser = ref.read(userProfileProvider).value;
    if (currentUser == null || _event == null) return;
    final participants = _event!.participants ?? [];
    setState(() {
      _hasJoined = participants.any((p) {
        if (p is EventUser) return p.id == currentUser.id;
        return p == currentUser.id;
      });
    });
  }

  Future<void> _toggleParticipation() async {
    if (_isJoining || _event == null) return;
    setState(() => _isJoining = true);

    try {
      final event = _hasJoined
          ? await eventService.leaveEvent(widget.id)
          : await eventService.joinEvent(widget.id);

      if (!mounted) return;
      setState(() {
        _event = _event?.merge(event) ?? event;
        _heroMediaIndex = _clampMediaIndexFor(_event);
        _isJoining = false;
      });
      _checkIfJoined();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
      setState(() => _isJoining = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_isOwner || _isTogglingSave) return;
    setState(() => _isTogglingSave = true);
    try {
      final summary = _saveSummary?.saved == true
          ? await saveService.unsaveEntity('event', widget.id)
          : await saveService.saveEntity('event', widget.id);
      if (!mounted) return;
      setState(() {
        _saveSummary = summary;
        _isTogglingSave = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTogglingSave = false);
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
    }
  }

  void _listenToSocketMessages() {
    _socketSubscription?.cancel();
    _socketSubscription = socketService.messages.listen((event) {
      if (!mounted) return;
      final eventName = event['event'];
      if (eventName == SocketEvents.eventUpdate) {
        final updatedEvent = _parseSocketEventUpdate(event['data']);
        if (updatedEvent == null || updatedEvent.id != widget.id) {
          return;
        }

        setState(() {
          _event = _event?.merge(updatedEvent) ?? updatedEvent;
          _heroMediaIndex = _clampMediaIndexFor(_event);
        });
        _checkIfJoined();
        return;
      }

      if (eventName == SocketEvents.threadCreate) {
        final payload = event['data'];
        final threadMap = payload is Map<String, dynamic>
            ? payload
            : payload is Map
            ? Map<String, dynamic>.from(payload)
            : null;
        if (threadMap == null) {
          return;
        }

        final thread = Thread.fromJson(threadMap);
        if (thread.eventId != widget.id || _event == null) {
          return;
        }

        final currentStats = _event!.stats;
        if (currentStats == null) {
          return;
        }

        setState(() {
          _event = _event!.copyWith(
            stats: EventStats(
              reactionCount: currentStats.reactionCount,
              threadCount: currentStats.threadCount + 1,
              participantCount: currentStats.participantCount,
              verifierCount: currentStats.verifierCount,
              mediaCount: currentStats.mediaCount,
              tagCount: currentStats.tagCount,
              viewCount: currentStats.viewCount,
              ratingCount: currentStats.ratingCount,
              ratingAverage: currentStats.ratingAverage,
            ),
          );
        });
      }
    });
  }

  Event? _parseSocketEventUpdate(dynamic payload) {
    final normalized = _extractSocketEventPayload(payload);
    if (normalized == null) {
      return null;
    }

    final eventId = normalized['id'];
    if (eventId is! String || eventId.isEmpty) {
      return null;
    }

    try {
      return Event.fromJson(normalized);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _extractSocketEventPayload(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final nested = payload['data'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
      return payload;
    }

    if (payload is Map) {
      final castPayload = Map<String, dynamic>.from(payload);
      final nested = castPayload['data'];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
      return castPayload;
    }

    return null;
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  void _openChat() {
    context.push('/event/${widget.id}/discussion');
  }

  Future<void> _openEditEvent() async {
    if (!_isOwner || _event == null || _isExpired) return;
    final updatedEvent = await context.push<Event>(
      CreateEventScreen.routePath,
      extra: _event,
    );
    if (!mounted || updatedEvent == null) return;
    setState(() {
      _event = _event?.merge(updatedEvent) ?? updatedEvent;
      _heroMediaIndex = _clampMediaIndexFor(_event);
    });
    await _loadEvent(showBlockingLoader: false);
  }

  Future<void> _shareEvent() async {
    final event = _event;
    if (event == null) return;

    final message = buildEventShareMessage(
      name: event.name,
      startTime: event.startTime,
      address: event.location.address,
      link: AppConfig.shareLink('/event/${widget.id}'),
    );

    // iPad needs an anchor rect for the share popover.
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: event.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Unable to share this event right now.');
    }
  }

  void _applyEngagementSummary(EngagementSummary summary) {
    final current = _event;
    if (current == null) return;

    final currentStats =
        current.stats ??
        EventStats(
          reactionCount: 0,
          threadCount: 0,
          participantCount: _participantCount,
          verifierCount: current.verifiers?.length ?? 0,
          mediaCount: current.media?.length ?? 0,
          tagCount: current.tags?.length ?? 0,
          viewCount: 0,
          ratingCount: 0,
          ratingAverage: 0,
        );

    setState(() {
      _engagementSummary = summary;
      _event = current.copyWith(
        stats: EventStats(
          reactionCount: currentStats.reactionCount,
          threadCount: currentStats.threadCount,
          participantCount: currentStats.participantCount,
          verifierCount: currentStats.verifierCount,
          mediaCount: currentStats.mediaCount,
          tagCount: currentStats.tagCount,
          viewCount: summary.viewCount,
          ratingCount: summary.ratingCount,
          ratingAverage: summary.ratingAverage,
        ),
      );
      _isLoadingEngagement = false;
    });
  }

  int _clampMediaIndexFor(Event? event) {
    final mediaCount = event?.media?.length ?? 0;
    if (mediaCount == 0) return 0;
    if (_heroMediaIndex >= mediaCount) {
      return mediaCount - 1;
    }
    return _heroMediaIndex;
  }

  List<Media> get _heroMedia => _event?.media ?? const [];

  String get _currentHeroMediaUrl {
    if (_heroMedia.isEmpty) {
      return 'https://picsum.photos/seed/${_event?.id ?? _defaultHeroImageSeed}/800/800';
    }
    return _heroMedia[_heroMediaIndex].url;
  }

  String get _eventDescription {
    final description = _event?.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }
    return _isHydratingFullEvent
        ? 'Loading event details...'
        : 'No description provided.';
  }

  String get _locationAddressLabel {
    final address = _event?.location.address.trim();
    if (address != null && address.isNotEmpty) {
      return address.toUpperCase();
    }
    return _defaultLocationLabel.toUpperCase();
  }

  String get _heroStatusLabel {
    final status = _event?.status.trim();
    if (status != null && status.isNotEmpty) {
      return status.toUpperCase();
    }
    return _defaultEventStatus.toUpperCase();
  }

  String get _heroTitle {
    final name = _event?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return _defaultEventName;
  }

  bool get _canShowFullEventDetails => _event?.hasFullDetail == true;

  String get _primaryTagLabel {
    final firstTag = _event?.tags?.isNotEmpty == true
        ? _event?.tags?.first
        : null;
    final tagName = firstTag?.name.trim() ?? '';
    return tagName.isNotEmpty ? tagName : _defaultPrimaryTag;
  }

  bool get _hasPreviousHeroMedia => _heroMediaIndex > 0;

  bool get _hasNextHeroMedia => _heroMediaIndex < _heroMedia.length - 1;

  void _toggleHeroExpanded() {
    setState(() => _isHeroExpanded = !_isHeroExpanded);
  }

  void _changeHeroMedia(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _heroMedia.length) return;
    setState(() {
      _heroMediaIndex = nextIndex;
      if (_isHeroExpanded) {
        _isHeroExpanded = false;
      }
    });
  }

  IconData _statusIconForEvent() {
    final event = _event;
    if (event == null) {
      return Icons.schedule_rounded;
    }

    switch (resolveEventStatus(event)) {
      case EventStatusValue.ongoing:
        return Icons.play_circle_fill_rounded;
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
        return Icons.check_circle_rounded;
      case EventStatusValue.upcoming:
      default:
        return Icons.schedule_rounded;
    }
  }

  IconData _minimizedStatusIconForEvent() {
    final event = _event;
    if (event == null) {
      return Icons.event_available_rounded;
    }

    switch (resolveEventStatus(event)) {
      case EventStatusValue.ongoing:
        return Icons.play_circle_filled_rounded;
      case EventStatusValue.completed:
      case EventStatusValue.cancelled:
        return Icons.task_alt_rounded;
      case EventStatusValue.upcoming:
      default:
        return Icons.event_available_rounded;
    }
  }

  Future<void> _openReviewComposer() async {
    if (_isSubmittingReview || _isOwner) return;

    final result = await showReviewEditorSheet(
      context,
      initialRating: _engagementSummary?.currentUserRating,
      initialReview: _engagementSummary?.currentUserReview,
    );

    if (result == null || !mounted) return;

    setState(() => _isSubmittingReview = true);
    try {
      final summary = result.action == ReviewEditorAction.delete
          ? await engagementService.deleteEntityRating('events', widget.id)
          : await engagementService.rateEntity(
              'events',
              widget.id,
              result.rating!,
              review: result.review,
            );

      if (!mounted) return;
      _applyEngagementSummary(summary);
      unawaited(_loadReviewPreview());
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
      setState(() => _isSubmittingReview = false);
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReview = false);
      }
    }
  }

  Future<void> _openRatingsPage() async {
    await context.push(
      EventRatingsScreen.routePath.replaceAll(':id', widget.id),
      extra: {'eventName': _event?.name ?? 'Event', 'isOwner': _isOwner},
    );
    if (!mounted) return;
    await _loadEngagement(silent: true);
  }

  static double _zoomForMapWidth(double width) {
    if (width >= 1200) return 11.0;
    if (width >= 900) return 12.0;
    if (width >= 600) return 13.0;
    return 14.0;
  }

  String _staticMapUrl({double zoom = 14}) {
    final lat = _event?.location.latitude;
    final lng = _event?.location.longitude;
    if (lat == null || lng == null) {
      return 'https://picsum.photos/seed/event-location/1200/600';
    }

    return _mapManager.getStaticMapImageUrl(
      latitude: lat,
      longitude: lng,
      width: 1200,
      height: 800,
      zoom: zoom,
      showMarker: false,
      fallbackUrl: 'https://picsum.photos/seed/event-location/1200/600',
    );
  }

  double get _locationMapHeight =>
      kIsWeb ? _webLocationMapHeight : _mobileLocationMapHeight;

  void _openAttendees() {
    context.push(
      EventAttendeesScreen.routePath,
      extra: {
        'eventName': _event?.name ?? 'Event',
        'attendees': _participantUsers,
        'capacity': _event?.capacity,
      },
    );
  }

  List<EventUser> get _participantUsers =>
      (_event?.participants ?? const []).whereType<EventUser>().toList();

  int get _participantCount => _event?.participants?.length ?? 0;

  EventStats get _eventStats =>
      _event?.stats ??
      EventStats(
        reactionCount: 0,
        threadCount: 0,
        participantCount: 0,
        verifierCount: 0,
        mediaCount: 0,
        tagCount: 0,
        viewCount: 0,
        ratingCount: 0,
        ratingAverage: 0,
      );

  String get _ratingMetaText {
    if (_eventStats.ratingCount == 0) return 'No ratings yet';
    return '${_eventStats.ratingAverage.toStringAsFixed(1)} (${_eventStats.ratingCount})';
  }

  List<_EventDetailAction> get _topActions {
    final currentUser = ref.read(userProfileProvider).value;
    final actions = <_EventDetailAction>[
      _EventDetailAction(
        key: _EventDetailActionKey.share,
        label: 'Share',
        icon: LucideIcons.share2,
        onTap: _shareEvent,
      ),
    ];

    if (_isOwner) {
      actions.insert(
        0,
        _EventDetailAction(
          key: _EventDetailActionKey.edit,
          label: 'Edit Event',
          icon: LucideIcons.pencil,
          onTap: _isExpired ? null : _openEditEvent,
          enabled: !_isExpired,
          tooltip: _isExpired
              ? "Can't edit this event because it has expired."
              : null,
        ),
      );
    } else if (currentUser != null) {
      actions.insert(
        0,
        _EventDetailAction(
          key: _EventDetailActionKey.save,
          label: _saveSummary?.saved == true ? 'Unsave Event' : 'Save Event',
          icon: _saveSummary?.saved == true
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          onTap: _toggleSave,
          loading: _isLoadingSaveState || _isTogglingSave,
        ),
      );
    }

    return actions;
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 420,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const AppSkeleton(),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.3),
                          AppColors.transparent,
                          AppColors.surface,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  const SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppSkeleton(
                            width: 40,
                            height: 40,
                            shape: BoxShape.circle,
                          ),
                          Row(
                            children: [
                              AppSkeleton(
                                width: 40,
                                height: 40,
                                shape: BoxShape.circle,
                              ),
                              SizedBox(width: 12),
                              AppSkeleton(
                                width: 40,
                                height: 40,
                                shape: BoxShape.circle,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSkeletonLine(width: 220, height: 28),
                  const SizedBox(height: 14),
                  const AppSkeletonLine(width: 172, height: 14),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: AppSkeleton(height: 84)),
                      SizedBox(width: 12),
                      Expanded(child: AppSkeleton(height: 84)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const AppSkeleton(
                    height: 120,
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                  ),
                  const SizedBox(height: 24),
                  const AppSkeletonLine(width: 140, height: 18),
                  const SizedBox(height: 16),
                  ...List.generate(
                    3,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: AppSkeleton(
                        height: 68,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
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

  @override
  Widget build(BuildContext context) {
    ref.watch(userProfileProvider);
    final typography = context.appTypography;

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_event == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Event not found'),
              TextButton(
                onPressed: () => context.go(ExploreScreen.routePath),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 420,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        key: ValueKey<String>(_currentHeroMediaUrl),
                        imageUrl: _currentHeroMediaUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 420,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.6),
                              AppColors.transparent,
                              AppColors.surface,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _circleButton(
                                LucideIcons.arrowLeft,
                                () => context.canPop()
                                    ? context.pop()
                                    : context.go(ExploreScreen.routePath),
                              ),
                              _buildTopActions(),
                            ],
                          ),
                        ),
                      ),
                      if (_hasPreviousHeroMedia)
                        Positioned(
                          left: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _carouselButton(
                              key: const ValueKey('hero-carousel-prev'),
                              icon: LucideIcons.chevronLeft,
                              onTap: () =>
                                  _changeHeroMedia(_heroMediaIndex - 1),
                            ),
                          ),
                        ),
                      if (_hasNextHeroMedia)
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _carouselButton(
                              key: const ValueKey('hero-carousel-next'),
                              icon: LucideIcons.chevronRight,
                              onTap: () =>
                                  _changeHeroMedia(_heroMediaIndex + 1),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 36,
                          ),
                          child: _buildHeroHeader(),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Avatar(
                              name: _event?.creator?.name ?? 'H',
                              imageUrl: _event?.creator?.avatarUrl,
                              size: 48,
                              textSize: 16,
                              imageBuilder: (context, child) => ColorFiltered(
                                colorFilter: const ColorFilter.mode(
                                  AppColors.mutedForeground,
                                  BlendMode.saturation,
                                ),
                                child: child,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('HOSTED BY', style: typography.overline),
                                  _isHydratingFullEvent &&
                                          _event?.creator == null
                                      ? const AppSkeletonLine(
                                          width: 120,
                                          height: 14,
                                        )
                                      : Text(
                                          _event?.creator?.name ?? 'Host',
                                          style: typography.titleSM,
                                        ),
                                ],
                              ),
                            ),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: AppColors.muted,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.messageCircle,
                                size: AppIconSizes.l,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'About the Event',
                                style: typography.titleMD,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _openChat,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.messageCircle,
                                      size: AppIconSizes.m,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Join Discussion',
                                      style: typography.bodySMStrong.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isHydratingFullEvent &&
                            (_event?.description?.trim() ?? '').isEmpty)
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppSkeletonLine(height: 14),
                              SizedBox(height: 6),
                              AppSkeletonLine(height: 14),
                              SizedBox(height: 6),
                              AppSkeletonLine(width: 180, height: 14),
                            ],
                          )
                        else
                          Text(_eventDescription, style: typography.bodyLG),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Location',
                                style: typography.titleMD,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: GestureDetector(
                                  onTap: () {
                                    final lat = _event?.location.latitude;
                                    final lng = _event?.location.longitude;
                                    if (lat != null && lng != null) {
                                      openInMaps(
                                        latitude: lat,
                                        longitude: lng,
                                        label: _event?.location.address,
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Open in Maps',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: typography.bodySMStrong.copyWith(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final mapZoom = _zoomForMapWidth(
                              constraints.maxWidth,
                            );
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: SizedBox(
                                height: _locationMapHeight,
                                width: double.infinity,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CachedNetworkImage(
                                        imageUrl: _staticMapUrl(zoom: mapZoom),
                                        fit: BoxFit.cover,
                                        placeholder: (_, _) =>
                                            Container(color: AppColors.muted),
                                        errorWidget: (_, _, _) =>
                                            Container(color: AppColors.muted),
                                      ),
                                    ),
                                    Center(
                                      child: Transform.translate(
                                        offset: const Offset(
                                          0,
                                          -_locationMapMarkerSize *
                                              _locationMapMarkerAnchorOffset,
                                        ),
                                        child: const SizedBox.square(
                                          dimension: _locationMapMarkerSize,
                                          child: CustomPaint(
                                            painter:
                                                UserLocationMapMarkerPainter(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Text(
                                          _locationAddressLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.overline.copyWith(
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        _guestListPreview(),
                        const SizedBox(height: 40),
                        _ratingsAndReviewsSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
              spacing: 16,
              children: [
                SizedBox(
                  width: 64,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: AppButton(
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.lg,
                      icon: const Icon(LucideIcons.messageCircle),
                      onPressed: _openChat,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    size: AppButtonSize.lg,
                    icon: _isJoining
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: AppColors.surface,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _hasJoined
                                ? LucideIcons.logOut
                                : LucideIcons.utensils,
                          ),
                    label: _hasJoined ? 'Leave Event' : 'Participate Now',
                    onPressed: _isJoining ? null : _toggleParticipation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestListPreview() {
    final typography = context.appTypography;
    final previewGuests = _participantUsers.take(4).toList();
    final isLoading = _isHydratingFullEvent && !_canShowFullEventDetails;

    return Column(
      key: const ValueKey('guest-list-preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Around the table', style: typography.titleLGStrong),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _openAttendees,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'View guest list',
                  style: typography.bodySMStrong.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 58,
          child: Row(
            children: [
              SizedBox(
                width: 142,
                height: 44,
                child: isLoading
                    ? Stack(
                        children: List.generate(
                          4,
                          (index) => Positioned(
                            left: index * 32,
                            top: 2,
                            child: const AppSkeleton(
                              width: 40,
                              height: 40,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                    : Stack(
                        children: List.generate(
                          previewGuests.length,
                          (index) => Positioned(
                            left: index * 32,
                            top: 2,
                            child: _guestAvatar(
                              user: previewGuests[index],
                              index: index,
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: isLoading
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppSkeletonLine(width: 124, height: 13),
                          SizedBox(height: 6),
                          AppSkeletonLine(width: 156, height: 10),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_participantCount ${_participantCount == 1 ? 'guest is' : 'guests are'} going',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.captionMD.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _participantCount == 0
                                ? 'Be the first to join the table'
                                : 'A shared table, mostly new faces',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: typography.labelSMRegular.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _guestAvatar({required EventUser user, required int index}) {
    final backgrounds = <Color>[
      AppColors.accent.withValues(alpha: 0.14),
      AppColors.warning.withValues(alpha: 0.14),
      AppColors.muted,
      AppColors.border,
    ];

    return Avatar(
      name: user.name,
      imageUrl: user.avatarUrl,
      size: 40,
      textSize: 12,
      borderColor: AppColors.surface,
      borderWidth: 2,
      backgroundColor: backgrounds[index % backgrounds.length],
    );
  }

  Widget _ratingsAndReviewsSection() {
    final summary =
        _engagementSummary ??
        EngagementSummary(
          viewCount: _eventStats.viewCount,
          ratingCount: _eventStats.ratingCount,
          ratingAverage: _eventStats.ratingAverage,
          ratingHistogram: const RatingHistogram(
            one: 0,
            two: 0,
            three: 0,
            four: 0,
            five: 0,
          ),
          currentUserRating: null,
          currentUserReview: null,
        );

    return EventRatingsPreview(
      summary: summary,
      recentReview: _recentCommunityReview,
      isOwner: _isOwner,
      isSubmitting: _isSubmittingReview,
      onOpenRatings: _openRatingsPage,
      onEditReview: _openReviewComposer,
    );
  }

  EventReview? get _recentCommunityReview {
    final currentUserId = ref.read(userProfileProvider).value?.id;
    for (final review in _eventReviews) {
      if (review.userId != currentUserId &&
          (review.review?.trim().isNotEmpty ?? false)) {
        return review;
      }
    }
    return null;
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: AppIconSizes.defaultSize,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildTopActions() {
    final typography = context.appTypography;
    final actions = _topActions;
    if (actions.length <= 2) {
      return Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            _buildTopActionButton(actions[index]),
            if (index != actions.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return PopupMenuButton<_EventDetailActionKey>(
      onSelected: (value) {
        final action = actions.firstWhere((item) => item.key == value);
        action.onTap?.call();
      },
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => actions
          .map(
            (action) => PopupMenuItem<_EventDetailActionKey>(
              value: action.key,
              enabled: action.enabled && !action.loading,
              child: Row(
                children: [
                  Icon(
                    action.icon,
                    size: AppIconSizes.defaultSize,
                    color: action.enabled
                        ? AppColors.primary
                        : AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.tooltip ?? action.label,
                      style: typography.labelMD.copyWith(
                        color: action.enabled
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: _circleButtonShell(
        const Icon(
          LucideIcons.moreVertical,
          size: AppIconSizes.defaultSize,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildTopActionButton(_EventDetailAction action) {
    final button = GestureDetector(
      onTap: action.enabled && !action.loading ? action.onTap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: action.loading
            ? const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            : Icon(
                action.icon,
                size: AppIconSizes.defaultSize,
                color: action.enabled
                    ? AppColors.primary
                    : AppColors.mutedForeground,
              ),
      ),
    );

    if (action.tooltip != null) {
      return Tooltip(message: action.tooltip, child: button);
    }
    return button;
  }

  Widget _circleButtonShell(Widget child) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _carouselButton({
    required Key key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.38),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface.withValues(alpha: 0.14)),
        ),
        child: Icon(
          icon,
          size: AppIconSizes.defaultSize,
          color: AppColors.surface,
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final typography = context.appTypography;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: _heroAnimationDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            16,
            _isHeroExpanded ? 14 : 12,
            16,
            _isHeroExpanded ? 16 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.surface.withValues(alpha: 0.1)),
          ),
          child: AnimatedSize(
            duration: _heroAnimationDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRect(
                  child: AnimatedAlign(
                    duration: _heroAnimationDuration,
                    curve: Curves.easeOutCubic,
                    heightFactor: _isHeroExpanded ? 1 : 0,
                    alignment: Alignment.bottomCenter,
                    child: ExcludeSemantics(
                      excluding: !_isHeroExpanded,
                      child: AnimatedOpacity(
                        duration: _heroAnimationDuration,
                        curve: Curves.easeOutCubic,
                        opacity: _isHeroExpanded ? 1 : 0,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: _isHeroExpanded ? 10 : 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.62,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _statusIconForEvent(),
                                            size: 12,
                                            color: AppColors.surface,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _heroStatusLabel,
                                            style: typography.overlineStrong
                                                .copyWith(
                                                  color: AppColors.surface,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    _verifiedHostChip(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _heroToggleButton(
                                icon: LucideIcons.chevronDown,
                                semanticLabel: 'Minimize hero header',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _heroTitle,
                        maxLines: _isHeroExpanded ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (_isHeroExpanded
                                    ? typography.heading1
                                    : typography.titleLGStrong)
                                .copyWith(color: AppColors.surface),
                      ),
                    ),
                    if (!_isHeroExpanded) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _minimizedStatusIconForEvent(),
                            size: 16,
                            color: AppColors.surface.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.surface.withValues(alpha: 0.9),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: _heroToggleButton(
                              icon: LucideIcons.chevronUp,
                              semanticLabel: 'Expand hero header',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                ClipRect(
                  child: AnimatedAlign(
                    duration: _heroAnimationDuration,
                    curve: Curves.easeOutCubic,
                    heightFactor: _isHeroExpanded ? 1 : 0,
                    alignment: Alignment.topCenter,
                    child: ExcludeSemantics(
                      excluding: !_isHeroExpanded,
                      child: AnimatedOpacity(
                        duration: _heroAnimationDuration,
                        curve: Curves.easeOutCubic,
                        opacity: _isHeroExpanded ? 1 : 0,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: _isHeroExpanded ? 8 : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 18,
                                    runSpacing: 8,
                                    children: [
                                      _engagementMeta(
                                        LucideIcons.eye,
                                        '${_eventStats.viewCount} views',
                                      ),
                                      GestureDetector(
                                        onTap: _openRatingsPage,
                                        child: _engagementMeta(
                                          LucideIcons.star,
                                          _ratingMetaText,
                                          isInteractive: true,
                                        ),
                                      ),
                                      if (_isLoadingEngagement)
                                        AppSkeleton(
                                          width: 16,
                                          height: 16,
                                          shape: BoxShape.circle,
                                          baseColor: AppColors.surface
                                              .withValues(alpha: 0.15),
                                          highlightColor: AppColors.surface
                                              .withValues(alpha: 0.4),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _infoPill(LucideIcons.timer, 'Active'),
                                      _infoPill(
                                        LucideIcons.utensils,
                                        _primaryTagLabel,
                                      ),
                                      _infoPill(
                                        LucideIcons.navigation,
                                        'Nearby',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroToggleButton({
    required IconData icon,
    required String semanticLabel,
  }) {
    return GestureDetector(
      key: ValueKey<String>('hero-toggle-$semanticLabel'),
      onTap: _toggleHeroExpanded,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: Icon(
              icon,
              size: AppIconSizes.defaultSize,
              color: AppColors.surface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _verifiedHostChip() {
    final typography = context.appTypography;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.badgeCheck,
              size: AppIconSizes.s,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Verified Host',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.bodyXSStrong.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            // Verifier avatar listing intentionally hidden for now.
          ],
        ),
      ),
    );
  }

  Widget _engagementMeta(
    IconData icon,
    String text, {
    bool isInteractive = false,
  }) {
    final typography = context.appTypography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Icon(
          icon,
          size: AppIconSizes.s,
          color: isInteractive
              ? AppColors.surface
              : AppColors.surface.withValues(alpha: 0.82),
        ),
        Text(
          text,
          style: typography.captionMD.copyWith(
            color: isInteractive
                ? AppColors.surface
                : AppColors.surface.withValues(alpha: 0.82),
            decoration: isInteractive
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _infoPill(IconData icon, String text) {
    final typography = context.appTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.surface.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(icon, size: AppIconSizes.m, color: AppColors.surface),
          Text(
            text,
            style: typography.bodySMStrong.copyWith(color: AppColors.surface),
          ),
        ],
      ),
    );
  }
}
