# Client Agent Guide

Apply this file together with the root [AGENTS.md](/Users/ashishpal/Desktop/coding/projects/bhandara/AGENTS.md).

## Stack

- Flutter
- Dart
- Riverpod codegen

## Commands

- Install deps: `flutter pub get`
- Analyze: `flutter analyze`
- Test: `flutter test`
- Codegen: `flutter pub run build_runner build --delete-conflicting-outputs`

For targeted work, prefer file-scoped commands first.

## Client Conventions

- Use semantic theme values from the app theme instead of hardcoded colors.
- Keep service logic in `lib/services/`.
- Keep provider logic in `lib/providers/`.
- Keep UI components reusable in `lib/widgets/` when they are shared across screens.

## Testing

- Prefer adding or updating focused widget/unit tests for behavioral changes.
- Run narrow tests first, then broader Flutter tests if the change spans multiple areas.

## Maintenance

- Keep this file client-specific.
- Put cross-repo rules in the root `AGENTS.md`, not here.
