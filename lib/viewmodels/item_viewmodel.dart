import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/analytics/services/report_registration_performance_tracker.dart';
import '../models/item_model.dart';
import '../models/campus_locations.dart';
import '../DAOs/item_dao.dart';
import '../services/campus_building_locator.dart';
import '../services/location_service.dart';

class ItemViewModel extends ChangeNotifier {
  ItemViewModel({
    this._itemDao = const ItemDao(),
    LocationService? locationService,
    this._firebaseAuth,
    this._tracker = const ReportRegistrationPerformanceTracker(),
    CampusBuildingLocator? buildingLocator,
  }) : _locationService = locationService ?? LocationService(),
       _buildingLocator =
           buildingLocator ??
           CampusBuildingLocator(buildings: defaultUniandesLocations);

  final ItemDao _itemDao;
  final LocationService _locationService;
  final FirebaseAuth? _firebaseAuth;
  final ReportRegistrationPerformanceTracker _tracker;
  final CampusBuildingLocator _buildingLocator;

  bool isLoading = false;
  bool isLoadingLocation = false;
  String? errorMessage;

  List<CampusLocation> locations = defaultUniandesLocations;
  CampusLocation? selectedLocation;

  /// How the suggested building was found; [BuildingMatch.unknown] means
  /// the student has to pick it.
  BuildingMatch buildingMatch = BuildingMatch.unknown;

  /// Detects the building the student is in from the GPS position and the
  /// building outlines, and orders the picker by distance.
  Future<void> loadPrioritizedLocations() async {
    isLoadingLocation = true;
    notifyListeners();

    try {
      final position = await _locationService.getCurrentLocation();
      final detection = _buildingLocator.locate(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
      locations = detection.ranked;
      buildingMatch = detection.match;
      // Only a confident detection is preselected; otherwise a wrong
      // building would be saved silently with the report.
      selectedLocation = detection.building;
    } catch (_) {
      locations = defaultUniandesLocations;
      buildingMatch = BuildingMatch.unknown;
      selectedLocation = null;
    } finally {
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  void selectLocation(CampusLocation? location) {
    selectedLocation = location;
    notifyListeners();
  }

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
