import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/item_model.dart';
import '../models/campus_locations.dart';
import '../DAOs/item_dao.dart';
import '../services/location_service.dart';

class ItemViewModel extends ChangeNotifier {
  final ItemDao _itemDao = ItemDao();
  final LocationService _locationService = LocationService();

  bool isLoading = false;
  bool isLoadingLocation = false;
  String? errorMessage;

  // Lista de ubicaciones del campus y la seleccionada actualmente
  List<CampusLocation> locations = defaultUniandesLocations;
  CampusLocation? selectedLocation;

  /// Carga la ubicación GPS actual y reordena el listado de edificios por cercanía
  Future<void> loadPrioritizedLocations() async {
    isLoadingLocation = true;
    notifyListeners();

    try {
      Position position = await _locationService.getCurrentLocation();
      
      final sortedList = List<CampusLocation>.from(defaultUniandesLocations);
      sortedList.sort((a, b) {
        final distA = a.distanceTo(position.latitude, position.longitude);
        final distB = b.distanceTo(position.latitude, position.longitude);
        return distA.compareTo(distB);
      });

      locations = sortedList;
    } catch (_) {
      // Si falla el GPS o deniegan permisos, dejamos el orden por defecto
      locations = defaultUniandesLocations;
    } finally {
      selectedLocation = locations.isNotEmpty ? locations.first : null;
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// Actualiza la ubicación seleccionada manualmente por el usuario en el formulario
  void selectLocation(CampusLocation? location) {
    selectedLocation = location;
    notifyListeners();
  }

  // Solo se encarga de empaquetar la ubicación y guardar el reporte
  Future<bool> reportItem({
    required String title,
    required String description,
    required String category,
    required String userEmail,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Si el usuario seleccionó un edificio específico, guardamos sus coordenadas de referencia.
      // Si prefieres usar la coordenada exacta del GPS en lugar del edificio, puedes descomentar la línea de abajo:
      // Position position = await _locationService.getCurrentLocation();

      final double lat = selectedLocation?.latitude ?? 4.6014;
      final double lng = selectedLocation?.longitude ?? -74.0661;

      // 2. Construye el modelo
      ItemModel newItem = ItemModel(
        title: title,
        description: description,
        category: category,
        location: GeoPoint(lat, lng), // Usa la ubicación seleccionada/sugerida
        userEmail: userEmail,
      );

      // 3. Lo guarda mediante el DAO
      await _itemDao.insertItem(newItem);

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
