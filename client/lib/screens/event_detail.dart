import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/theme.dart';
import '../widgets/button.dart';
import '../widgets/snackbar.dart';
import '../widgets/map_view.dart';
import '../utils/error.dart';
import '../services/event.dart';
import '../models/event.dart';
import '../services/socket.dart';
import '../constants/socket_events.dart';
import '../providers/user.dart';
import '../services/maps/map_manager.dart';
import '../services/maps/map_provider_type.dart';

import 'explore.dart';
import 'chat.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.id});

  static const String routePath = '/event/:id';
  final String id;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  Event? _event;
  bool _isLoading = true;
  bool _isJoining = false;
  bool _hasJoined = false;
  final MapManager _mapManager = MapManager(type: MapProviderType.google);

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);

    try {
      final event = await eventService.getEvent(widget.id);
      if (mounted) {
        setState(() {
          _event = event;
          _isLoading = false;
        });
        _checkIfJoined();
        _connectSocket();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkIfJoined() {
    final currentUser = ref
        .read(userProfileProvider)
        .value;
    if (currentUser == null || _event == null) return;
    final participants = _event!.participants ?? [];
    setState(() {
      _hasJoined = participants.any((p) => p == currentUser.id);
    });
  }

  Future<void> _toggleParticipation() async {
    if (_isJoining || _event == null) return;
    setState(() => _isJoining = true);

    try {
      final event = _hasJoined
          ? await eventService.leaveEvent(widget.id)
          : await eventService.joinEvent(widget.id);

      if (mounted) {
        setState(() {
          _event = event;
          _hasJoined = !_hasJoined;
          _isJoining = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final message = extractExceptionMessage(e);
        AppSnackBar.show(context, message: message, type: SnackBarType.error);
        setState(() => _isJoining = false);
      }
    }
  }

  void _connectSocket() {
    socketService.connect(widget.id);
    socketService.messages.listen((event) {
      if (!mounted) return;
      final eventName = event['event'];
      final eventData = event['data'];
      setState(() {
        if (eventName == SocketEvents.eventUpdated) {
          final updatedEvent = Event.fromJson(eventData);
          if (updatedEvent.id == widget.id) {
            _event = updatedEvent;
            _checkIfJoined();
          }
        }
      });
    });
  }

  LatLng _eventLatLng() {
    final lat = _event?.location.latitude;
    final lng = _event?.location.longitude;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return const LatLng(21.1458, 79.0882);
  }

  Set<Marker> _eventMarkers() {
    final lat = _event?.location.latitude;
    final lng = _event?.location.longitude;
    if (lat == null || lng == null) return const <Marker>{};

    return {
      Marker(
        markerId: MarkerId(_event!.id),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        infoWindow: InfoWindow(title: _event!.name),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
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
                // Hero
                SizedBox(
                  height: 420,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: _event!.media?.isNotEmpty == true
                            ? _event!.media!.first.url
                            : 'https://picsum.photos/seed/${_event!
                            .id}/800/800',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 420,
                      ),
                      // Gradient overlay
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

                      // Top buttons
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
                                    () => context.go(ExploreScreen.routePath),
                              ),
                              Row(
                                children: [
                                  _circleButton(LucideIcons.heart, () {}),
                                  const SizedBox(width: 12),
                                  _circleButton(LucideIcons.share2, () {}),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Bottom content overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
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
                                    child: Text(
                                      _event!.status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Row(
                                    children: [
                                      Icon(
                                        LucideIcons.badgeCheck,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified Host',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _event!.name,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
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
                                  _infoPill(LucideIcons.navigation, 'Nearby'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
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
                        // Host
                        Row(
                          children: [
                            ClipOval(
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.border,
                                    width: 2,
                                  ),
                                ),
                                child: ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.mutedForeground,
                                    BlendMode.saturation,
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                    'https://picsum.photos/seed/host/100/100',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HOSTED BY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 2,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                  Text(
                                    'Host User',
                                    style: TextStyle(
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
                                size: 24,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // About
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'About the Event',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  context.go(
                                    ChatScreen.routePath.replaceAll(
                                      ':id',
                                      _event!.id.toString(),
                                    ),
                                  ),
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
                                      size: 16,
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
                          _event!.description ?? "No description provided.",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Location
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
                                AppMapView(
                                  manager: _mapManager,
                                  initialCameraPosition: CameraPosition(
                                    target: _eventLatLng(),
                                    zoom: 14,
                                  ),
                                  markers: _eventMarkers(),
                                  zoomControlsEnabled: false,
                                  myLocationButtonEnabled: false,
                                  myLocationEnabled: false,
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

                        // Who's going
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Who's Going",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '24 Attending',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 40,
                          child: Stack(
                            children: [
                              ...List.generate(4, (i) {
                                return Positioned(
                                  left: i * 28.0,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: ColorFiltered(
                                        colorFilter: const ColorFilter.mode(
                                          AppColors.mutedForeground,
                                          BlendMode.saturation,
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                          'https://picsum.photos/seed/user${i +
                                              1}/100/100',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              Positioned(
                                left: 4 * 28.0,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.muted,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '+20',
                                      style: TextStyle(
                                        fontSize: 10,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sticky bottom
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Row(
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
                      label: 'Chat',
                      onPressed: () =>
                          context.go(
                            ChatScreen.routePath.replaceAll(':id', widget.id),
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
        child: Icon(icon, size: 20, color: AppColors.primary),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
