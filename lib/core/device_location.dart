import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'api_client.dart';

/// Fetches a fresh foreground location only after the user requests it.
Future<Position> currentDeviceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ApiException(
      'Hãy bật Vị trí trong cài đặt thiết bị, rồi thử lại hoặc nhập tọa độ.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const ApiException(
      'Quyền vị trí đã bị chặn. Vào Cài đặt → Ứng dụng → Smart Farm → Quyền → Vị trí để cho phép.',
    );
  }
  if (permission != LocationPermission.whileInUse &&
      permission != LocationPermission.always) {
    throw const ApiException(
      'Chưa được cấp quyền vị trí. Cho phép khi dùng ứng dụng hoặc nhập tọa độ thủ công.',
    );
  }
  final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (android &&
      await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
    // Existing installs may have coarse permission from the previous manifest.
    // Android shows the upgrade dialog; users can keep approximate access.
    permission = await Geolocator.requestPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const ApiException(
        'Chưa được cấp quyền vị trí. Hãy kiểm tra quyền của Smart Farm.',
      );
    }
  }
  const settings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 15),
  );
  try {
    return await Geolocator.getCurrentPosition(locationSettings: settings);
  } on TimeoutException {
    if (!android) rethrow;
    // Android's network/fused provider may not produce a fix on an emulator.
    // Retry via the system location provider; never substitute stale coordinates.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          forceLocationManager: true,
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      final recent = await Geolocator.getLastKnownPosition();
      final age = recent == null
          ? null
          : DateTime.now().difference(recent.timestamp);
      if (recent != null &&
          age != null &&
          !age.isNegative &&
          age <= const Duration(minutes: 2) &&
          recent.accuracy.isFinite &&
          recent.accuracy >= 0 &&
          recent.accuracy <= 100 &&
          recent.latitude.isFinite &&
          recent.latitude.abs() <= 90 &&
          recent.longitude.isFinite &&
          recent.longitude.abs() <= 180) {
        return recent;
      }
      rethrow;
    }
  }
}
