// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserSettings)
final userSettingsProvider = UserSettingsProvider._();

final class UserSettingsProvider
    extends $AsyncNotifierProvider<UserSettings, user_models.UserSettings?> {
  UserSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSettingsHash();

  @$internal
  @override
  UserSettings create() => UserSettings();
}

String _$userSettingsHash() => r'c9bac77b366f819e0a11581bbce0706260ab08bc';

abstract class _$UserSettings
    extends $AsyncNotifier<user_models.UserSettings?> {
  FutureOr<user_models.UserSettings?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<user_models.UserSettings?>,
              user_models.UserSettings?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<user_models.UserSettings?>,
                user_models.UserSettings?
              >,
              AsyncValue<user_models.UserSettings?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
