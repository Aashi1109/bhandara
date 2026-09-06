import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/features/profile/models/user.dart';
import 'package:foody_mobile/shared/providers/user.dart';
import 'package:foody_mobile/features/settings/screens/profile_details.dart';
import 'package:foody_mobile/shared/theme/theme.dart';
import 'package:foody_mobile/shared/widgets/button.dart';
import 'package:foody_mobile/shared/widgets/skeleton.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  final baseUser = User(
    id: 'user-1',
    email: 'test@example.com',
    name: 'Ashish',
    gender: 'male',
    bio: 'Food explorer',
  );

  testWidgets('initial render keeps update button disabled', (tester) async {
    final profile = _TestUserProfile(baseUser);

    await _pumpProfileDetails(tester, profile);

    expect(_updateButton(tester).onPressed, isNull);

    await tester.tap(find.text('Update Profile'));
    await tester.pumpAndSettle();

    expect(profile.updateProfileCalls, 0);
  });

  testWidgets('editing display name enables save and calls update once', (
    tester,
  ) async {
    final profile = _TestUserProfile(baseUser);

    await _pumpProfileDetails(tester, profile);

    await tester.enterText(find.byType(TextField).first, 'Ashish Pal');
    await tester.pump();

    expect(_updateButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Update Profile'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(profile.updateProfileCalls, 1);
    expect(profile.updates.single['name'], 'Ashish Pal');
    expect(profile.updates.single['bio'], 'Food explorer');
    expect(_updateButton(tester).onPressed, isNull);

    await tester.tap(find.text('Update Profile'));
    await tester.pumpAndSettle();

    expect(profile.updateProfileCalls, 1);
  });

  testWidgets('editing bio alone enables save and calls update once', (
    tester,
  ) async {
    final profile = _TestUserProfile(baseUser);

    await _pumpProfileDetails(tester, profile);

    await tester.enterText(find.byType(TextField).at(1), 'Writes dinner notes');
    await tester.pump();

    expect(_updateButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Update Profile'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(profile.updateProfileCalls, 1);
    expect(profile.updates.single['name'], 'Ashish');
    expect(profile.updates.single['bio'], 'Writes dinner notes');
    expect(_updateButton(tester).onPressed, isNull);
  });

  testWidgets('editing gender alone enables save and calls update once', (
    tester,
  ) async {
    final profile = _TestUserProfile(baseUser);

    await _pumpProfileDetails(tester, profile);

    await tester.tap(find.text('Female'));
    await tester.pump();

    expect(_updateButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Update Profile'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(profile.updateProfileCalls, 1);
    expect(profile.updates.single['name'], 'Ashish');
    expect(profile.updates.single['bio'], 'Food explorer');
    expect(profile.updates.single['gender'], 'female');
    expect(_updateButton(tester).onPressed, isNull);
  });

  testWidgets('reverting trimmed text disables save again', (tester) async {
    final profile = _TestUserProfile(baseUser);

    await _pumpProfileDetails(tester, profile);

    await tester.enterText(find.byType(TextField).first, 'Ashish Pal');
    await tester.pump();
    expect(_updateButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField).first, '  Ashish  ');
    await tester.pump();

    expect(_updateButton(tester).onPressed, isNull);

    await tester.tap(find.text('Update Profile'));
    await tester.pumpAndSettle();

    expect(profile.updateProfileCalls, 0);
  });

  testWidgets('shows profile skeletons while user data is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith(() => _LoadingUserProfile()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(lightPalette),
          home: const ProfileDetailsScreen(),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(AppSkeleton), findsWidgets);
  });
}

Future<void> _pumpProfileDetails(
  WidgetTester tester,
  _TestUserProfile profile,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [userProfileProvider.overrideWith(() => profile)],
      child: MaterialApp(
        theme: AppTheme.buildTheme(lightPalette),
        home: const ProfileDetailsScreen(),
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
}

AppButton _updateButton(WidgetTester tester) {
  return tester.widget<AppButton>(
    find.widgetWithText(AppButton, 'Update Profile'),
  );
}

class _TestUserProfile extends UserProfile {
  _TestUserProfile(this._user);

  User _user;
  int updateProfileCalls = 0;
  final List<Map<String, String?>> updates = [];

  @override
  FutureOr<User?> build() async => _user;

  @override
  Future<void> updateProfile({
    String? name,
    String? bio,
    String? gender,
    String? mediaId,
  }) async {
    updateProfileCalls += 1;
    updates.add({
      'name': name,
      'bio': bio,
      'gender': gender,
      'mediaId': mediaId,
    });

    state = const AsyncLoading();
    await Future<void>.delayed(Duration.zero);

    _user = User(
      id: _user.id,
      email: _user.email,
      name: name ?? _user.name,
      username: _user.username,
      gender: gender ?? _user.gender,
      avatarUrl: _user.avatarUrl,
      bio: bio ?? _user.bio,
      createdAt: _user.createdAt,
      meta: _user.meta,
      address: _user.address,
      isSocialLogin: _user.isSocialLogin,
    );
    state = AsyncData(_user);
  }
}

class _LoadingUserProfile extends UserProfile {
  @override
  FutureOr<User?> build() => Completer<User?>().future;
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _TestHttpResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _transparentImage.length;

  @override
  HttpHeaders get headers => _TestHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const [];

  @override
  Future<Socket> detachSocket() {
    throw UnimplementedError();
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  String get reasonPhrase => 'OK';

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnimplementedError();
  }

  @override
  Future<T> fold<T>(
    T initialValue,
    T Function(T previous, List<int> element) combine,
  ) async {
    return combine(initialValue, _transparentImage);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  List<String>? operator [](String name) {
    if (name.toLowerCase() == HttpHeaders.contentTypeHeader) {
      return <String>['image/png'];
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final Uint8List _transparentImage = Uint8List.fromList(const <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0xC9,
  0xFE,
  0x92,
  0xEF,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
