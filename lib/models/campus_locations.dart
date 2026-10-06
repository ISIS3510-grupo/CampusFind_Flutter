import 'dart:math';

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

  double distanceTo(double lat, double lng) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat - latitude) * p) / 2 +
        cos(latitude * p) * cos(lat * p) * (1 - cos((lng - longitude) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }
}

const List<CampusLocation> defaultUniandesLocations = [
  CampusLocation(
    id: 'ML',
    name: 'Edificio Mario Laserna (ML)',
    latitude: 4.601489,
    longitude: -74.066125,
  ),
  CampusLocation(
    id: 'W',
    name: 'Edificio Carlos Angulo Rueda (W)',
    latitude: 4.602280,
    longitude: -74.065260,
  ),
  CampusLocation(
    id: 'SD',
    name: 'Edificio Santo Domingo (SD)',
    latitude: 4.600980,
    longitude: -74.065830,
  ),
  CampusLocation(
    id: 'RGD',
    name: 'Edificio Alberto Lleras Camargo (RGD)',
    latitude: 4.602790,
    longitude: -74.065480,
  ),
  CampusLocation(
    id: 'LL',
    name: 'Edificio Lleras (LL)',
    latitude: 4.602490,
    longitude: -74.065980,
  ),
];