import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_farm/core/api_client.dart';
import 'package:smart_farm/core/device_location.dart';

class TestLocation extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int requests = 0, timeouts = 0;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;
  final settings = <LocationSettings>[];
  Position? cached;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => cached;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settings.add(locationSettings!);
    if (settings.length <= timeouts) throw TimeoutException('GPS unavailable');
    return Position(
      longitude: 106.6,
      latitude: 10.8,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late TestLocation platform;
  setUp(() {
    final previous = GeolocatorPlatform.instance;
    platform = TestLocation();
    GeolocatorPlatform.instance = platform;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      GeolocatorPlatform.instance = previous;
      debugDefaultTargetPlatformOverride = null;
    });
  });
  test('requests permission and a fresh high accuracy fix', () async {
    platform.permission = LocationPermission.denied;
    expect((await currentDeviceLocation()).latitude, 10.8);
    expect(platform.requests, 1);
    expect(platform.settings.single.accuracy, LocationAccuracy.high);
  });
  test(
    'disabled and permanently denied location never fetch coordinates',
    () async {
      platform.enabled = false;
      await expectLater(currentDeviceLocation(), throwsA(isA<ApiException>()));
      platform.enabled = true;
      platform.permission = LocationPermission.deniedForever;
      await expectLater(
        currentDeviceLocation(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Cài đặt'),
          ),
        ),
      );
      expect(platform.requests, 0);
      expect(platform.settings, isEmpty);
    },
  );
  test('denied runtime permission is respected', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;
    await expectLater(currentDeviceLocation(), throwsA(isA<ApiException>()));
    expect(platform.settings, isEmpty);
  });
  test('upgraded install requests precise access through Android permission dialog', () async {
    platform.accuracy = LocationAccuracyStatus.reduced;
    await currentDeviceLocation();
    expect(platform.requests, 1);
    expect(platform.settings, hasLength(1));
  });
  test('Android timeout retries the native provider', () async {
    platform.timeouts = 1;
    expect((await currentDeviceLocation()).longitude, 106.6);
    expect(platform.settings, hasLength(2));
    expect(
      (platform.settings.last as AndroidSettings).forceLocationManager,
      isTrue,
    );
  });
  test(
    'both providers timing out return an error without invented coordinates',
    () async {
      platform.timeouts = 2;
      await expectLater(
        currentDeviceLocation(),
        throwsA(isA<TimeoutException>()),
      );
      expect(platform.settings, hasLength(2));
    },
  );
  test(
    'fresh accurate last fix works; stale coordinates are rejected',
    () async {
      platform.timeouts = 2;
      platform.cached = Position(
        longitude: 106.6,
        latitude: 10.8,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      expect((await currentDeviceLocation()).latitude, 10.8);
      platform.settings.clear();
      platform.cached = Position(
        longitude: 106.6,
        latitude: 10.8,
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      await expectLater(
        currentDeviceLocation(),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
  test(
    'other platforms never invoke the Android provider on timeout',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      platform.timeouts = 1;
      await expectLater(
        currentDeviceLocation(),
        throwsA(isA<TimeoutException>()),
      );
      expect(platform.settings, hasLength(1));
    },
  );
}
