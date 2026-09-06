import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/local_storage.dart';
import '../theme/palettes.dart';

part 'theme_preference.g.dart';

@Riverpod(keepAlive: true)
class ThemePreference extends _$ThemePreference {
  static const _key = 'theme_preference';

  @override
  Future<String> build() async {
    final stored = await localStorage.get<String>(_key);
    return stored != null && (stored == 'system' || paletteById(stored) != null)
        ? stored
        : 'system';
  }

  Future<void> setPreference(String id) async {
    if (id != 'system' && paletteById(id) == null) return;
    state = AsyncData(id);
    await localStorage.set(_key, id);
  }
}
