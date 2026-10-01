import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/item_model.dart';
import '../DAOs/item_dao.dart';
import '../services/location_service.dart';

class ItemViewModel extends ChangeNotifier {
  final ItemDao _itemDao = ItemDao();
  final LocationService _locationService = LocationService();

  bool isLoading = false;
  String? errorMessage;

  //Solo se encarga de empaquetar la ubicación y guardar el reporte
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
      // 1. Pide la ubicación al servicio de GPS
      Position position = await _locationService.getCurrentLocation();

      // 2. Construye el modelo
      ItemModel newItem = ItemModel(
        title: title,
        description: description,
        category: category,
        location: GeoPoint(position.latitude, position.longitude),
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
