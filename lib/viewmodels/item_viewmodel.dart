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

  List<CampusLocation> locations = defaultUniandesLocations;
  CampusLocation? selectedLocation;


 String? locationMessage; // mensaje para mostrar en la UI

Future<void> loadPrioritizedLocations() async {
  isLoadingLocation = true;
  locationMessage = null;
  notifyListeners();

  final position = await _locationService.getCurrentLocation();

  if (position == null) {
    selectedLocation = null;
    locationMessage =
        'No pudimos obtener tu ubicación. Selecciona el edificio manualmente.';
  } else {
    final nearest = _locationService.findNearestLocation(
      userLat: position.latitude,
      userLng: position.longitude,
      locations: locations,
    );

    if (nearest == null) {
      selectedLocation = null;
    } else {
      double distance =
          nearest.distanceTo(position.latitude, position.longitude);

      if (distance <= LocationService.maxDistanceToCampusMeters) {
        selectedLocation = nearest;
      } else {
        selectedLocation = null;
        locationMessage =
            'Parece que no estás en el campus. Selecciona el edificio manualmente.';
      }
    }
  }

  isLoadingLocation = false;
  notifyListeners();
}

  void selectLocation(CampusLocation? location) {
    selectedLocation = location;
    notifyListeners();
  }

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
      final double lat = selectedLocation?.latitude ?? 4.601489;
      final double lng = selectedLocation?.longitude ?? -74.066125;

      ItemModel newItem = ItemModel(
        title: title,
        description: description,
        category: category,
        location: GeoPoint(lat, lng),
        userEmail: userEmail,
      );

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