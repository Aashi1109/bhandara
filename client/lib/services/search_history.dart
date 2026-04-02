import 'dart:convert';

import '../models/search_event_item.dart';
import 'local_storage.dart';

class SearchHistoryService {
  SearchHistoryService({LocalStorage? storage})
    : _storage = storage ?? LocalStorage(namespace: 'search');

  static const String _historyKey = 'event_history';
  static const int _maxItems = 10;

  final LocalStorage _storage;

  Future<List<SearchEventItem>> getHistory() async {
    final rawEntries = await _storage.get<List<dynamic>>(_historyKey);
    final items = (rawEntries ?? const <dynamic>[])
        .whereType<String>()
        .map((entry) => _decodeItem(entry))
        .whereType<SearchEventItem>()
        .toList();
    return items;
  }

  Future<void> addSelection(SearchEventItem item) async {
    final current = await getHistory();
    final next = <SearchEventItem>[
      item,
      ...current.where((existing) => existing.id != item.id),
    ].take(_maxItems).toList();

    await _storage.set(
      _historyKey,
      next.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }

  SearchEventItem? _decodeItem(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return SearchEventItem.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

final searchHistoryService = SearchHistoryService();
