// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tagsHash() => r'59e65458e1aba47dc9f8580d0a72423449045a57';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [tags].
@ProviderFor(tags)
const tagsProvider = TagsFamily();

/// See also [tags].
class TagsFamily extends Family<AsyncValue<List<Tag>>> {
  /// See also [tags].
  const TagsFamily();

  /// See also [tags].
  TagsProvider call({bool rootOnly = false}) {
    return TagsProvider(rootOnly: rootOnly);
  }

  @override
  TagsProvider getProviderOverride(covariant TagsProvider provider) {
    return call(rootOnly: provider.rootOnly);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tagsProvider';
}

/// See also [tags].
class TagsProvider extends AutoDisposeFutureProvider<List<Tag>> {
  /// See also [tags].
  TagsProvider({bool rootOnly = false})
    : this._internal(
        (ref) => tags(ref as TagsRef, rootOnly: rootOnly),
        from: tagsProvider,
        name: r'tagsProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tagsHash,
        dependencies: TagsFamily._dependencies,
        allTransitiveDependencies: TagsFamily._allTransitiveDependencies,
        rootOnly: rootOnly,
      );

  TagsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.rootOnly,
  }) : super.internal();

  final bool rootOnly;

  @override
  Override overrideWith(FutureOr<List<Tag>> Function(TagsRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: TagsProvider._internal(
        (ref) => create(ref as TagsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        rootOnly: rootOnly,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Tag>> createElement() {
    return _TagsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TagsProvider && other.rootOnly == rootOnly;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, rootOnly.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TagsRef on AutoDisposeFutureProviderRef<List<Tag>> {
  /// The parameter `rootOnly` of this provider.
  bool get rootOnly;
}

class _TagsProviderElement extends AutoDisposeFutureProviderElement<List<Tag>>
    with TagsRef {
  _TagsProviderElement(super.provider);

  @override
  bool get rootOnly => (origin as TagsProvider).rootOnly;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
