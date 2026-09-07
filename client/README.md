# foody_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Google Maps Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Create env file from template:

```bash
cp env.dev.example.json .env.dev.json
```

3. Fill values in `.env.dev.json`.
   Add backend host values for your current runtime:

- Android emulator: `"API_HOST": "10.0.2.2"`
- Physical device: `"API_HOST": "<your-laptop-lan-ip>"`
- Optional: `"API_PORT": "3000"`, `"API_SCHEME": "http"`

4. Run with dart define file:

```bash
flutter run --dart-define-from-file=.env.dev.json
```

5. Build with same env file:

```bash
flutter build apk --dart-define-from-file=.env.dev.json
flutter build ios --dart-define-from-file=.env.dev.json
```

6. Enable billing and APIs in Google Cloud Console:

- Maps SDK for Android
- Maps SDK for iOS
- Street View Static API (for coordinate-based preview images in Explore)

## Map Provider Switch (Factory Pattern)

Map integrations now live under `lib/services/maps/` with provider-specific services and a manager:

- `google_maps_service.dart`
- `mapbox_maps_service.dart`
- `map_manager.dart`

Instantiate manager once with provider type, then call methods on that manager:

```dart
final mapManager = MapManager(type: MapProviderType.google);
final place = await mapManager.getAddressFromCoordinates(
  latitude: 21.1702,
  longitude: 79.6527,
);
```

```dart
final mapManager = MapManager(type: MapProviderType.mapbox);
final results = await mapManager.searchPlaces(
  query: 'Nagpur',
);
```

Provider keys are read inside each service from env:

- Google: `GOOGLE_MAPS_API_KEY`
- Google web cloud styling: `GOOGLE_MAPS_WEB_MAP_ID` (optional, preferred on web)
- Google Android cloud styling: `GOOGLE_MAPS_ANDROID_MAP_ID` (optional, preferred on Android)
- Google iOS cloud styling: `GOOGLE_MAPS_IOS_MAP_ID` (optional, preferred on iOS)
- Mapbox: `MAPBOX_ACCESS_TOKEN` (`MAPBOX_STYLE_ID` optional)
- Backend: `API_HOST` (`API_PORT` and `API_SCHEME` optional)

This app supports two Google Maps styling paths:

- Preferred: set the platform map ID (`GOOGLE_MAPS_WEB_MAP_ID`, `GOOGLE_MAPS_ANDROID_MAP_ID`, `GOOGLE_MAPS_IOS_MAP_ID`) and manage the style in Google Cloud
- Fallback: omit the platform map ID and the app will use the local legacy JSON style

Do not use both on the same platform map. When a platform `mapId` is present,
the app intentionally skips local JSON styling and lets cloud styling own the
map appearance.
