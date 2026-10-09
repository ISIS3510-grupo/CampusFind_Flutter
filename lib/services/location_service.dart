/* import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/campus_locations.dart';

class LocationService {
  static const String _googleApiKey = 'AIzaSyBV4lIfhte1hKT-mfSWbJ3OqHmKic52Oqw';

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

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  /// Calcula la distancia real desde el GPS a cada edificio usando Google Maps Distance Matrix API
  Future<List<CampusLocation>> sortLocationsByGoogleMaps({
    required double userLat,
    required double userLng,
    required List<CampusLocation> locations,
  }) async {
    if (locations.isEmpty) return locations;

    // Construir lista de destinos "lat,lng|lat,lng|..."
    final destinations = locations
        .map((loc) => '${loc.latitude},${loc.longitude}')
        .join('|');

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=$userLat,$userLng'
      '&destinations=$destinations'
      '&mode=walking'
      '&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['rows'] != null &&
            (data['rows'] as List).isNotEmpty) {
          final elements = data['rows'][0]['elements'] as List;

          List<MapEntry<CampusLocation, int>> locationWithDistances = [];

          for (int i = 0; i < locations.length; i++) {
            final element = elements[i];
            if (element['status'] == 'OK') {
              final distanceInMeters = element['distance']['value'] as int;
              locationWithDistances.add(MapEntry(locations[i], distanceInMeters));
            } else {
              // Si falla un elemento específico, usamos el cálculo local como fallback
              final fallbackDist = locations[i].distanceTo(userLat, userLng).toInt();
              locationWithDistances.add(MapEntry(locations[i], fallbackDist));
            }
          }

          // Ordenar de menor a mayor distancia
          locationWithDistances.sort((a, b) => a.value.compareTo(b.value));
          return locationWithDistances.map((e) => e.key).toList();
        }
      }
    } catch (_) {
      // Si falla la red o la API, fallback a ordenamiento local por Haversine
    }

    // Fallback local en caso de error
    final sortedList = List<CampusLocation>.from(locations);
    sortedList.sort((a, b) =>
        a.distanceTo(userLat, userLng).compareTo(b.distanceTo(userLat, userLng)));
    return sortedList;
  }
}
 */

import 'package:geolocator/geolocator.dart';
import '../models/campus_locations.dart';

class LocationService {
  // Si el usuario está más lejos que esto del edificio más cercano,
  // se considera fuera del campus y no se sugiere nada.
  static const double maxDistanceToCampusMeters = 400;

  // Devuelve la posición del GPS, o null si no se pudo obtener.
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  // Devuelve el edificio más cercano (distancia en línea recta).
  CampusLocation? findNearestLocation({
    required double userLat,
    required double userLng,
    required List<CampusLocation> locations,
  }) {
    CampusLocation? nearest;
    double minDistance = double.infinity;

    for (int i = 0; i < locations.length; i++) {
      double distance = locations[i].distanceTo(userLat, userLng);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = locations[i];
      }
    }
    return nearest;
  }
}