import 'dart:async';

import 'package:campusfind_flutter/features/drop_off/data/office_location_repository.dart';
import 'package:campusfind_flutter/features/drop_off/domain/office_location.dart';
import 'package:campusfind_flutter/features/drop_off/services/maps_launcher_service.dart';

class FakeOfficeLocationRepository extends OfficeLocationRepository {
  FakeOfficeLocationRepository() : super(officeId: 'office-test');

  OfficeLocation? office = const OfficeLocation(
    id: 'office-test',
    name: 'Mario Laserna',
    latitude: 4.60275,
    longitude: -74.06482,
  );
  Object? error;
  Completer<OfficeLocation?>? pending;
  int calls = 0;

  @override
  Future<OfficeLocation?> getOfficeLocation() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? office : await pending!.future;
  }
}

class FakeMapsLauncherService extends MapsLauncherService {
  bool result = true;
  Object? error;
  Completer<bool>? pending;
  final List<({double latitude, double longitude})> destinations = [];

  @override
  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    destinations.add((latitude: latitude, longitude: longitude));
    if (error != null) throw error!;
    return pending == null ? result : await pending!.future;
  }
}
