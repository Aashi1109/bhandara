import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  final String? namespace;
  static SharedPreferences? _prefs;
  static Completer<SharedPreferences>? _initCompleter;

  LocalStorage({this.namespace});

  static Future<void> init() async {
    if (_prefs != null) return;
    if (_initCompleter != null) return _initCompleter!.future.then((_) {});

    _initCompleter = Completer<SharedPreferences>();
    try {
      final instance = await SharedPreferences.getInstance();
      _prefs = instance;
      _initCompleter!.complete(instance);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<SharedPreferences> get _instance async {
    if (_prefs != null) return _prefs!;
    await init();
    return _prefs!;
  }

  String _buildKey(String key) => namespace != null ? '$namespace:$key' : key;

  Future<void> set(String key, dynamic value) async {
    final k = _buildKey(key);
    final prefs = await _instance;
    if (value is String) {
      await prefs.setString(k, value);
    } else if (value is bool) {
      await prefs.setBool(k, value);
    } else if (value is int) {
      await prefs.setInt(k, value);
    } else if (value is double) {
      await prefs.setDouble(k, value);
    } else if (value is List<String>) {
      await prefs.setStringList(k, value);
    }
  }

  Future<T?> get<T>(String key) async {
    final prefs = await _instance;
    final value = prefs.get(_buildKey(key));
    return value as T?;
  }

  Future<void> remove(String key) async {
    final prefs = await _instance;
    await prefs.remove(_buildKey(key));
  }

  Future<void> clear() async {
    final prefs = await _instance;
    if (namespace == null) {
      await prefs.clear();
    } else {
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('$namespace:')) {
          await prefs.remove(key);
        }
      }
    }
  }
}

final localStorage = LocalStorage();
