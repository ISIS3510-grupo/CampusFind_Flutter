import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
 
import '../DAOs/item_dao.dart';
import '../models/campus_locations.dart';
import '../models/item_model.dart';
import '../services/location_service.dart';
 
 //itemviewmodel is incharge of logical vlaidations

class ItemViewModel extends ChangeNotifier {
  ItemViewModel({
    ItemDao itemDao = const ItemDao(),
    LocationService? locationService,
    FirebaseAuth? firebaseAuth,
  }) : _itemDao = itemDao,
       _locationService = locationService ?? LocationService(),
       _firebaseAuth = firebaseAuth;
 
  final ItemDao _itemDao;
  final LocationService _locationService;
  final FirebaseAuth? _firebaseAuth;
 
  bool isLoading = false;
  bool isLoadingLocation = false;
  String? errorMessage;
 
  List<CampusLocation> locations = defaultUniandesLocations;
  CampusLocation? selectedLocation;
 
  /// Lee el GPS, ordena los edificios por cercania y preselecciona el primero.
  void loadPrioritizedLocations() {
    isLoadingLocation = true;
    notifyListeners();
 
    _locationService.getCurrentLocation((position) {
      if (position != null) {
        locations = _locationService.sortByDistance(
          userLat: position.latitude,
          userLng: position.longitude,
          locations: defaultUniandesLocations,
        );
      } else {
        locations = defaultUniandesLocations;
      }
      selectedLocation = locations.isNotEmpty ? locations.first : null;
      isLoadingLocation = false;
      notifyListeners();
    });
  }
 
  void selectLocation(CampusLocation? location) {
    selectedLocation = location;
    notifyListeners();
  }
 
  /// Crea el reporte. El resultado llega por [onDone] (true = guardado).
  void reportItem({
    required String reportType,
    required String title,
    required String description,
    required String category,
    required void Function(bool ok) onDone,
  }) {
    if (isLoading) return;//tells if there is a process 
 
    final userUid = (_firebaseAuth ?? FirebaseAuth.instance).currentUser?.uid;
    final building = selectedLocation;
 
    if (userUid == null || userUid.isEmpty) {
      errorMessage = 'Please sign in before reporting an item.';
      notifyListeners();
      onDone(false);
      return;
    }
    if (building == null) {
      errorMessage = 'Please select a location.';
      notifyListeners();
      onDone(false);
      return;
    }
 
    isLoading = true;
    errorMessage = null;
    notifyListeners();
 
    final item = ItemModel(
      title: title,
      description: description,
      category: category,
      location: GeoPoint(building.latitude, building.longitude),
    );
 
    _itemDao.insertItem(
      item,
      reportType: reportType,
      userUid: userUid,
      locationName: building.name,
      onSuccess: () {
        isLoading = false;
        notifyListeners();
        onDone(true);
      },
      onError: (message) {
        isLoading = false;
        errorMessage = message;
        notifyListeners();
        onDone(false);
      },
    );
  }
}
 
