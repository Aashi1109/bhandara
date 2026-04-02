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

String _$loginFlowHash() => r'608335cfc4f288150763be115be1ca18fe09eb43';

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
