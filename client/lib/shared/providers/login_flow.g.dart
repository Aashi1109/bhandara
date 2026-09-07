// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_flow.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LoginFlow)
final loginFlowProvider = LoginFlowProvider._();

final class LoginFlowProvider
    extends $NotifierProvider<LoginFlow, LoginFlowState> {
  LoginFlowProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loginFlowProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loginFlowHash();

  @$internal
  @override
  LoginFlow create() => LoginFlow();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoginFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoginFlowState>(value),
    );
  }
}

String _$loginFlowHash() => r'fa9fc61b22dc3940b0af114b501a2fb8ecf2c900';

abstract class _$LoginFlow extends $Notifier<LoginFlowState> {
  LoginFlowState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<LoginFlowState, LoginFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LoginFlowState, LoginFlowState>,
              LoginFlowState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
