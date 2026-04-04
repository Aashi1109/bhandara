import 'package:flutter_test/flutter_test.dart';
import 'package:foody_mobile/screens/explore/utils/explore_viewport.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dart_geohash/dart_geohash.dart';

Set<String> _referenceVisibleGeohashTiles({
  required LatLng sw,
  required LatLng ne,
  required double zoom,
}) {
  final precision = geohashPrecisionFromZoom(zoom);
  final totalBits = precision * 5;
  final lngBits = (totalBits / 2).ceil();
  final latBits = totalBits ~/ 2;
  final latStep = 180.0 / (1 << latBits);
  final lngStep = 360.0 / (1 << lngBits);
  final geoHasher = GeoHasher();

  final tiles = <String>{};
  var lat = sw.latitude;
  while (lat <= ne.latitude + latStep) {
    var lng = sw.longitude;
    while (lng <= ne.longitude + lngStep) {
      tiles.add(
        geoHasher.encode(
          lng.clamp(-180.0, 180.0),
          lat.clamp(-90.0, 90.0),
          precision: precision,
        ),
      );
      lng += lngStep;
    }
    lat += latStep;
  }

  return tiles;
}

void main() {
  test(
    'buildExploreCacheLocationKey separates follow location and viewport',
    () {
      final followKey = buildExploreCacheLocationKey(
        mode: ExploreMapQueryMode.followLocation,
        followLocation: const LatLng(19.076, 72.8777),
        followRadiusKm: 25,
      );
      final viewportKey = buildExploreCacheLocationKey(
        mode: ExploreMapQueryMode.viewport,
        viewport: const ExploreViewportQuery(
          center: LatLng(19.076, 72.8777),
          radiusKm: 18.4,
          zoom: 12.3,
        ),
      );

      expect(followKey, startsWith('follow|'));
      expect(viewportKey, startsWith('viewport|'));
      expect(followKey, isNot(equals(viewportKey)));
    },
  );

  test(
    'hasMeaningfulViewportChange ignores tiny shifts but catches major ones',
    () {
      const previous = ExploreViewportQuery(
        center: LatLng(19.076, 72.8777),
        radiusKm: 12,
        zoom: 13,
      );

      const tinyShift = ExploreViewportQuery(
        center: LatLng(19.0762, 72.8779),
        radiusKm: 12.2,
        zoom: 13.05,
      );
      const majorShift = ExploreViewportQuery(
        center: LatLng(19.096, 72.8977),
        radiusKm: 16,
        zoom: 13.4,
      );

      expect(hasMeaningfulViewportChange(previous, tinyShift), isFalse);
      expect(hasMeaningfulViewportChange(previous, majorShift), isTrue);
    },
  );

  test('viewportRadiusKmFromCorners uses farthest corner with buffer', () {
    const center = LatLng(19.076, 72.8777);
    const corners = <LatLng>[
      LatLng(19.176, 72.9777),
      LatLng(18.976, 72.7777),
      LatLng(19.176, 72.7777),
      LatLng(18.976, 72.9777),
    ];

    final radiusKm = viewportRadiusKmFromCorners(
      center: center,
      corners: corners,
      bufferMultiplier: 1.1,
    );
    final unbufferedKm = distanceBetweenLatLng(center, corners.first) / 1000;

    expect(radiusKm, greaterThan(unbufferedKm));
    expect(radiusKm, closeTo(unbufferedKm * 1.1, 0.15));
  });

  test(
    'computeVisibleGeohashTiles matches reference grid at odd precision 5',
    () {
      const sw = LatLng(19.00, 72.80);
      const ne = LatLng(19.18, 72.98);

      final actual = computeVisibleGeohashTiles(sw: sw, ne: ne, zoom: 13.0);
      final expected = _referenceVisibleGeohashTiles(
        sw: sw,
        ne: ne,
        zoom: 13.0,
      );

      expect(actual, expected);
    },
  );

  test(
    'computeVisibleGeohashTiles matches reference grid at odd precision 7',
    () {
      const sw = LatLng(19.378, 72.810);
      const ne = LatLng(19.381, 72.814);

      final actual = computeVisibleGeohashTiles(sw: sw, ne: ne, zoom: 18.0);
      final expected = _referenceVisibleGeohashTiles(
        sw: sw,
        ne: ne,
        zoom: 18.0,
      );

      expect(actual, expected);
    },
  );
}
