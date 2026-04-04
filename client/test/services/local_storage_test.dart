// ignore_for_file: depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/services/local_storage.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorage', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    tearDown(() {
      SharedPreferencesAsyncPlatform.instance = null;
    });

    test('supports typed values and namespace-aware clearing', () async {
      await LocalStorage.init();

      final rootStorage = LocalStorage();
      final userStorage = LocalStorage(namespace: 'user');
      final searchStorage = LocalStorage(namespace: 'search');

      await rootStorage.set('flag', true);
      await rootStorage.set('count', 3);
      await rootStorage.set('ratio', 2.5);
      await rootStorage.set('title', 'Foody');
      await rootStorage.set('tags', <String>['a', 'b']);

      await userStorage.set('onboarded', true);
      await userStorage.set('favorites', <String>['event-1', 'event-2']);
      await searchStorage.set('history', <String>['search-1']);

      expect(await rootStorage.get<bool>('flag'), isTrue);
      expect(await rootStorage.get<int>('count'), 3);
      expect(await rootStorage.get<double>('ratio'), 2.5);
      expect(await rootStorage.get<String>('title'), 'Foody');
      expect(await rootStorage.get<List<String>>('tags'), <String>['a', 'b']);
      expect(await userStorage.get<bool>('onboarded'), isTrue);
      expect(await userStorage.get<List<String>>('favorites'), <String>[
        'event-1',
        'event-2',
      ]);

      await userStorage.remove('onboarded');
      expect(await userStorage.get<bool>('onboarded'), isNull);

      await userStorage.clear();

      expect(await userStorage.get<List<String>>('favorites'), isNull);
      expect(await rootStorage.get<bool>('flag'), isTrue);
      expect(await searchStorage.get<List<String>>('history'), <String>[
        'search-1',
      ]);

      await rootStorage.clear();

      expect(await rootStorage.get<bool>('flag'), isNull);
      expect(await rootStorage.get<int>('count'), isNull);
      expect(await rootStorage.get<double>('ratio'), isNull);
      expect(await rootStorage.get<String>('title'), isNull);
      expect(await rootStorage.get<List<String>>('tags'), isNull);
      expect(await searchStorage.get<List<String>>('history'), isNull);
    });
  });
}
