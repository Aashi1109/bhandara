// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tags)
final tagsProvider = TagsFamily._();

final class TagsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Tag>>,
          List<Tag>,
          FutureOr<List<Tag>>
        >
    with $FutureModifier<List<Tag>>, $FutureProvider<List<Tag>> {
  TagsProvider._({
    required TagsFamily super.from,
    required ({bool rootOnly, String? parentId}) super.argument,
  }) : super(
         retry: null,
         name: r'tagsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tagsHash();

  @override
  String toString() {
    return r'tagsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<Tag>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Tag>> create(Ref ref) {
    final argument = this.argument as ({bool rootOnly, String? parentId});
    return tags(ref, rootOnly: argument.rootOnly, parentId: argument.parentId);
  }

  @override
  bool operator ==(Object other) {
    return other is TagsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tagsHash() => r'd8217d35407a589d809e688f78dbcac2e2a7957c';

final class TagsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Tag>>,
          ({bool rootOnly, String? parentId})
        > {
  TagsFamily._()
    : super(
        retry: null,
        name: r'tagsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TagsProvider call({bool rootOnly = false, String? parentId}) =>
      TagsProvider._(
        argument: (rootOnly: rootOnly, parentId: parentId),
        from: this,
      );

  @override
  String toString() => r'tagsProvider';
}
