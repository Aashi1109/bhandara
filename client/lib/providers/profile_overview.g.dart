// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_overview.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileOverview)
final profileOverviewProvider = ProfileOverviewFamily._();

final class ProfileOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<ProfileOverview>,
          ProfileOverview,
          FutureOr<ProfileOverview>
        >
    with $FutureModifier<ProfileOverview>, $FutureProvider<ProfileOverview> {
  ProfileOverviewProvider._({
    required ProfileOverviewFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileOverviewProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileOverviewHash();

  @override
  String toString() {
    return r'profileOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ProfileOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ProfileOverview> create(Ref ref) {
    final argument = this.argument as String;
    return profileOverview(ref, userId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileOverviewHash() => r'524c951d140cf85881e40dedd3cb3011f3a985b0';

final class ProfileOverviewFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ProfileOverview>, String> {
  ProfileOverviewFamily._()
    : super(
        retry: null,
        name: r'profileOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileOverviewProvider call({required String userId}) =>
      ProfileOverviewProvider._(argument: userId, from: this);

  @override
  String toString() => r'profileOverviewProvider';
}
