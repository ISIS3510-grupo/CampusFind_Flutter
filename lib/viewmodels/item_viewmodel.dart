import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../features/analytics/services/report_registration_performance_tracker.dart';
import '../models/item_model.dart';
import '../models/campus_locations.dart';
import '../DAOs/item_dao.dart';
import '../services/location_service.dart';

class ItemViewModel extends ChangeNotifier {
  ItemViewModel({
    this._itemDao = const ItemDao(),
    LocationService? locationService,
    this._firebaseAuth,
    this._tracker = const ReportRegistrationPerformanceTracker(),
  }) : _locationService = locationService ?? LocationService();

  final ItemDao _itemDao;
  final LocationService _locationService;
  final FirebaseAuth? _firebaseAuth;
  final ReportRegistrationPerformanceTracker _tracker;

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
    required String reportType,
    required String title,
    required String description,
    required String category,
  }) async {
    if (isLoading) return false;
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final userUid = (_firebaseAuth ?? FirebaseAuth.instance).currentUser?.uid;
      if (userUid == null || userUid.isEmpty) {
        throw StateError('Please sign in before reporting an item.');
      }
      await _tracker.measure(
        reportType: reportType,
        operation: () async {
          // The building suggested by GPS (or picked by the student) is the
          // reported place; the raw GPS position is only a fallback.
          final building = selectedLocation;
          final GeoPoint location;
          if (building != null) {
            location = GeoPoint(building.latitude, building.longitude);
          } else {
            final position = await _locationService.getCurrentLocation();
            location = GeoPoint(position.latitude, position.longitude);
          }
          final item = ItemModel(
            title: title,
            description: description,
            category: category,
            location: location,
          );
          await _itemDao.insertItem(
            item,
            reportType: reportType,
            userUid: userUid,
            locationName: building?.name,
          );
        },
      );

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
