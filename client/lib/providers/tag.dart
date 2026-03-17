import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/event.dart';
import '../services/tag.dart';

part 'tag.g.dart';

@riverpod
Future<List<Tag>> tags(Ref ref, {
  bool rootOnly = false,
  String? parentId,
}) => tagService.getTags(rootOnly: rootOnly, parentId: parentId);
