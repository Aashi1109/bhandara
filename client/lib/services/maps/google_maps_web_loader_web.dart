// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

const _googleMapsScriptId = 'google-maps-javascript-sdk';
const _loadedState = 'loaded';

Completer<void>? _loaderCompleter;

Future<void> ensureGoogleMapsWebSdkLoaded(String apiKey) {
  if (apiKey.isEmpty) {
    return Future.error(
      StateError('GOOGLE_MAPS_API_KEY is required to render maps on web.'),
    );
  }

  if (_loaderCompleter != null) {
    return _loaderCompleter!.future;
  }

  _loaderCompleter = Completer<void>();

  final existingScript = html.document.getElementById(_googleMapsScriptId);
  if (existingScript is html.ScriptElement) {
    if (existingScript.dataset['state'] == _loadedState) {
      _completeLoader();
      return _loaderCompleter!.future;
    }

    existingScript.onError.first.then((_) {
      _completeLoaderWithError(
        StateError('Failed to load the Google Maps JavaScript SDK.'),
      );
    });
    existingScript.onLoad.first.then((_) {
      existingScript.dataset['state'] = _loadedState;
      _completeLoader();
    });
    return _loaderCompleter!.future;
  }

  final script = html.ScriptElement()
    ..id = _googleMapsScriptId
    ..async = true
    ..defer = true
    ..src =
        'https://maps.googleapis.com/maps/api/js?key=$apiKey&loading=async&v=weekly';

  script.onError.first.then((_) {
    _completeLoaderWithError(
      StateError('Failed to load the Google Maps JavaScript SDK.'),
    );
  });
  script.onLoad.first.then((_) {
    script.dataset['state'] = _loadedState;
    _completeLoader();
  });

  html.document.head?.append(script);
  return _loaderCompleter!.future;
}

void _completeLoader() {
  if (!(_loaderCompleter?.isCompleted ?? true)) {
    _loaderCompleter?.complete();
  }
}

void _completeLoaderWithError(Object error) {
  if (!(_loaderCompleter?.isCompleted ?? true)) {
    _loaderCompleter?.completeError(error);
  }
}
