import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// Crea una instancia desde un documento de Firestore.
  factory CampusLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    /* final geo = data['location'];
    final double lat = geo is GeoPoint
        ? geo.latitude
        : (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final double lng = geo is GeoPoint
        ? geo.longitude
        : (data['longitude'] as num?)?.toDouble() ?? 0.0; */

    return CampusLocation(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'latitude': latitude, 'longitude': longitude};
  }

  double distanceTo(double lat, double lng) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        cos((lat - latitude) * p) / 2 +
        cos(latitude * p) * cos(lat * p) * (1 - cos((lng - longitude) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }
}

/// Lista de respaldo (fallback) en caso de fallar la consulta a Firestore o no haber conexión.
const List<CampusLocation> defaultUniandesLocations = [
  CampusLocation(
    id: 'ML',
    name: 'Edificio Mario Laserna (ML)',
    latitude: 4.6031162,
    longitude: -74.0651005,
  ),
  CampusLocation(
    id: 'Aulas',
    name: 'Edificio Aulas (AU)',
    latitude: 4.6026728,
    longitude: -74.0662405,
  ),
  CampusLocation(
    id: 'SD',
    name: 'Edificio Santo Domingo (SD)',
    latitude: 4.6042338,
    longitude: -74.0658991,
  ),
  CampusLocation(
    id: 'RGD',
    name: 'Centro Cívico',
    latitude: 4.6023860,
    longitude: -74.0660745,
  ),
  CampusLocation(
    id: 'LL',
    name: 'Edificio Lleras (LL)',
    latitude: 4.6019993,
    longitude: -74.0652765,
  ),
];
