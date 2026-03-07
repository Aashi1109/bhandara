import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final String? namespace;
  final _storage = const FlutterSecureStorage();

  SecureStorage({this.namespace});

  AndroidOptions get _androidOptions =>
      const AndroidOptions(encryptedSharedPreferences: true);

  String _buildKey(String key) => namespace != null ? '$namespace:$key' : key;

  Future<void> write(String key, String value) async {
    await _storage.write(
      key: _buildKey(key),
      value: value,
      aOptions: _androidOptions,
    );
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: _buildKey(key), aOptions: _androidOptions);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: _buildKey(key), aOptions: _androidOptions);
  }

  Future<void> clear() async {
    if (namespace == null) {
      await _storage.deleteAll(aOptions: _androidOptions);
    } else {
      final all = await _storage.readAll(aOptions: _androidOptions);
      for (final key in all.keys) {
        if (key.startsWith('$namespace:')) {
          await _storage.delete(key: key, aOptions: _androidOptions);
        }
      }
    }
  }
}

final secureStorage = SecureStorage();
