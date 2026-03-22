import 'dart:ui';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../constants/socket_events.dart';
import '../models/chat.dart';
import '../models/engagement.dart';
import '../models/event.dart';
import '../models/save.dart';
import '../providers/user.dart';
import '../services/chat.dart';
import '../services/engagement.dart';
import '../services/event.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/map_provider_type.dart';
import '../services/save.dart';
import '../services/socket.dart';
import '../theme/theme.dart';
import '../utils/event_status.dart';
import '../utils/error.dart';
import '../widgets/avatar.dart';
import '../widgets/button.dart';
import '../widgets/review_editor_sheet.dart';
import '../widgets/snackbar.dart';
import 'chat.dart';
import 'create_event.dart';
import 'event_attendees.dart';
import 'event_ratings.dart';
import 'explore.dart';

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

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Event? _event;
  EngagementSummary? _engagementSummary;
  bool _isLoading = true;
  bool _isHydratingFullEvent = false;
  bool _isLoadingEngagement = false;
  bool _isJoining = false;
  bool _isOpeningChat = false;
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingEngagement = false);
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
        _event = event;
        _hasJoined = !_hasJoined;
        _isJoining = false;
      });
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
      final eventData = event['data'];
      setState(() {
        if (eventName == SocketEvents.eventUpdated) {
          final updatedEvent = Event.fromJson(eventData);
          if (updatedEvent.id == widget.id) {
            _event = _event?.merge(updatedEvent) ?? updatedEvent;
            _heroMediaIndex = _clampMediaIndexFor(_event);
            _checkIfJoined();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openChat() async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);

    try {
      final result = await chatService.getEventThreads(widget.id, limit: 20);
      Thread? selected;

      if (result.items.isNotEmpty) {
        selected = result.items.firstWhere(
          (thread) => thread.type == 'general',
          orElse: () => result.items.first,
        );
      } else {
        selected = await chatService.createThread(widget.id, type: 'general');
      }

      if (!mounted) return;
      context.go(
        ChatScreen.routePath.replaceAll(':id', selected.id),
        extra: {'eventId': widget.id},
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: extractExceptionMessage(e),
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
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

  void _shareEvent() {
    AppSnackBar.info(context, 'Share is not available yet.');
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
      return 'https://picsum.photos/seed/${_event!.id}/800/800';
    }
    return _heroMedia[_heroMediaIndex].url;
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

  String _staticMapUrl() {
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
      zoom: 14,
      showMarker: true,
      fallbackUrl: 'https://picsum.photos/seed/event-location/1200/600',
    );
  }

  void _openAttendees() {
    if (_participantUsers.isEmpty) return;

    context.push(
      EventAttendeesScreen.routePath,
      extra: {
        'eventName': _event?.name ?? 'Event',
        'attendees': _participantUsers,
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

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(userProfileProvider).value;
    if (currentUser != null &&
        !_isOwner &&
        _saveSummary == null &&
        !_isLoadingSaveState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _saveSummary == null && !_isLoadingSaveState) {
          _loadSaveState();
        }
      });
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
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
                                  const Text(
                                    'HOSTED BY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  Text(
                                    _event?.creator?.name ??
                                        (_isHydratingFullEvent
                                            ? 'Loading host...'
                                            : 'Host'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
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
                            const Expanded(
                              child: Text(
                                'About the Event',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      LucideIcons.messageCircle,
                                      size: AppIconSizes.m,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Join Discussion',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
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
                        Text(
                          _event!.description ??
                              (_isHydratingFullEvent
                                  ? 'Loading event details...'
                                  : 'No description provided.'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Open in Maps',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            height: 176,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: CachedNetworkImage(
                                    imageUrl: _staticMapUrl(),
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) =>
                                        Container(color: AppColors.muted),
                                    errorWidget: (_, _, _) =>
                                        Container(color: AppColors.muted),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      _event!.location.address.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Who's Going",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _participantUsers.isEmpty
                                  ? null
                                  : _openAttendees,
                              child: Text(
                                _isHydratingFullEvent && !_event!.hasFullDetail
                                    ? 'Loading attendees...'
                                    : '$_participantCount Attending',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _participantUsers.isEmpty
                                      ? AppColors.mutedForeground
                                      : AppColors.primary,
                                  decoration: _participantUsers.isEmpty
                                      ? TextDecoration.none
                                      : TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_participantUsers.isEmpty && _isHydratingFullEvent)
                          const SizedBox(
                            height: 40,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                        else if (_participantUsers.isEmpty)
                          const SizedBox(
                            height: 40,
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                'No attendees yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mutedForeground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 52,
                            child: Stack(
                              children: [
                                ...List.generate(
                                  _participantUsers.take(4).length,
                                  (i) => Positioned(
                                    left: i * 34.0,
                                    child: _avatarBubble(
                                      user: _participantUsers[i],
                                      size: 52,
                                      textSize: 13,
                                      borderColor: AppColors.surface,
                                    ),
                                  ),
                                ),
                                if (_participantCount > 4)
                                  Positioned(
                                    left: 4 * 34.0,
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.muted,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '+${_participantCount - 4}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
                Expanded(
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
                    icon: _isJoining || _isOpeningChat
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
                    onPressed: _isJoining || _isOpeningChat
                        ? null
                        : _toggleParticipation,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingsAndReviewsSection() {
    final hasRatings = _eventStats.ratingCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasRatings ? 'Ratings & Reviews' : 'No review yet',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: hasRatings || _isOwner
                  ? _openRatingsPage
                  : (_isSubmittingReview ? null : _openReviewComposer),
              child: Text(
                hasRatings
                    ? '${_eventStats.ratingCount} ratings'
                    : _isOwner
                    ? 'No reviews yet'
                    : 'Be the first to review',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isSubmittingReview && !hasRatings
                      ? AppColors.mutedForeground
                      : AppColors.primary,
                  decoration: hasRatings || !_isOwner
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
        if (_engagementSummary?.currentUserRating != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Your Review',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    ...List.generate(
                      5,
                      (index) => Icon(
                        index < (_engagementSummary?.currentUserRating ?? 0)
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (!_isOwner)
                      GestureDetector(
                        onTap: _isSubmittingReview ? null : _openReviewComposer,
                        child: Icon(
                          LucideIcons.pencil,
                          color: _isSubmittingReview
                              ? AppColors.mutedForeground
                              : AppColors.primary,
                          size: AppIconSizes.defaultSize,
                        ),
                      ),
                  ],
                ),
                if ((_engagementSummary?.currentUserReview ?? '')
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _engagementSummary!.currentUserReview!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
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
                                      _event!.status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _verifiedHostChip(),
                                ),
                              ),
                              const Spacer(),
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
                        _event!.name,
                        maxLines: _isHeroExpanded ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _isHeroExpanded ? 36 : 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          letterSpacing: -0.5,
                          color: AppColors.surface,
                        ),
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
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.surface,
                                          ),
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
                                        _event!.tags?.isNotEmpty == true
                                            ? _event!.tags!.first.name
                                            : 'Food',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.muted.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(
                LucideIcons.badgeCheck,
                size: AppIconSizes.s,
                color: AppColors.primary,
              ),
              Flexible(
                child: Text(
                  'Verified Host',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              // Verifier avatar listing intentionally hidden for now.
            ],
          ),
        );
      },
    );
  }

  Widget _avatarBubble({
    required EventUser user,
    required double size,
    required double textSize,
    required Color borderColor,
  }) {
    return Avatar(
      name: user.name,
      imageUrl: user.avatarUrl,
      size: size,
      textSize: textSize,
      borderColor: borderColor,
      borderWidth: 2,
    );
  }

  Widget _engagementMeta(
    IconData icon,
    String text, {
    bool isInteractive = false,
  }) {
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
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
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
