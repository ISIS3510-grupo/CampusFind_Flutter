import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  static const _maxLastKnownAge = Duration(minutes: 2);

  /// Obtiene la ubicación GPS actual con máxima precisión
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están desactivados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Los permisos de ubicación están denegados permanentemente.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      // Indoors a fresh fix can take longer than the form should wait. The
      // last known position carries its own accuracy, so the building
      // locator still decides whether it is precise enough to use. An old
      // fix may come from somewhere else, so only a recent one counts.
      final lastKnown = await Geolocator.getLastKnownPosition();
      final age = lastKnown == null
          ? null
          : DateTime.now().difference(lastKnown.timestamp);
      if (lastKnown == null || age! > _maxLastKnownAge) rethrow;
      return lastKnown;
    }
  }
}
