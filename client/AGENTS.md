# Mobile Agent Instructions

## Package Manager

Use **flutter**: `flutter pub get`, `flutter pub upgrade`,
`flutter pub run build_runner build --delete-conflicting-outputs`

## Required Skills

The following skills MUST be activated and used for all work in the `/mobile` directory:

- `flutter-expert`: For all UI, navigation, and state management logic.
- `mobile-developer`: For platform-specific configurations and general mobile best practices.
- `mobile-design`: To ensure premium UI/UX, responsiveness, and consistent design language.
- `native-data-fetching`: For Dio services, WebSocket integration, and error handling.
- `mobile-security-coder`: For handling secure storage and sensitive authentication data.
- `agent-memory`: **CRITICAL**: Always use this skill at the start of any task or when context is
  needed. Proactively use it to **save new memories** about architectural decisions, complex
  patterns, or important user preferences discovered during work.
- `agent-memory-mcp`: Use this to maintain and access structured, persistent architectural memory.

- **Networking**: Use `ApiService` (`dio`) for REST and `SocketService` (`web_socket_channel`) for
  real-time features.
- **Styling**: DO NOT use colors directly (e.g., `Colors.red`). ALWAYS use semantic colors from
  `AppColors` defined in `lib/theme/theme.dart`.

## Development Workflow

- **Web-First Prototyping**: Always build and verify the UI in the web part of the project first.
- **Project Path**: The primary web/source project is located at
  `/Users/ashishpal/Desktop/coding/projects/foody`.
- **Design Validation**: Ensure the web UI exactly matches the design specifications before porting.
- **Mobile Replication**: Once validated on web, replicate the UI and logic in this mobile client to
  maintain feature parity and design consistency.

## File-Scoped Commands

| Task         | Command                                                           |
|--------------|-------------------------------------------------------------------|
| Analyze      | `flutter analyze lib/path/to/file.dart`                           |
| Test         | `flutter test test/path/to/file_test.dart`                        |
| Build Runner | `flutter pub run build_runner build --delete-conflicting-outputs` |
