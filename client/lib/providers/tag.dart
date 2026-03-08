import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/event.dart';
import '../services/tag.dart';

part 'tag.g.dart';

@riverpod
Future<List<Tag>> tags(TagsRef ref, {bool rootOnly = false}) async {
  final response = await tagService.getTags(rootOnly: rootOnly);
  if (response.data != null) {
    return response.data!;
  }
  throw Exception(response.error ?? 'Failed to fetch tags');
}
