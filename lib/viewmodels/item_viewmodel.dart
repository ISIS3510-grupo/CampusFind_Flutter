import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/analytics/services/report_registration_performance_tracker.dart';
import '../models/item_model.dart';
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
  String? errorMessage;

  //Solo se encarga de empaquetar la ubicación y guardar el reporte
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
          final position = await _locationService.getCurrentLocation();
          final item = ItemModel(
            title: title,
            description: description,
            category: category,
            location: GeoPoint(position.latitude, position.longitude),
          );
          await _itemDao.insertItem(
            item,
            reportType: reportType,
            userUid: userUid,
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
