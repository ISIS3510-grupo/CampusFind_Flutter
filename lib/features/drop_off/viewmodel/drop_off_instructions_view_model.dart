import 'package:flutter/foundation.dart';

import '../data/office_location_repository.dart';
import '../domain/office_location.dart';

class DropOffInstructionsViewModel extends ChangeNotifier {
  DropOffInstructionsViewModel({required this._repository});

  final OfficeLocationRepository _repository;
  OfficeLocation? _officeLocation;
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;

  OfficeLocation? get officeLocation => _officeLocation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_isLoading || _disposed) return;
    _isLoading = true;
    _errorMessage = null;
    _officeLocation = null;
    notifyListeners();
    try {
      final location = await _repository.getOfficeLocation();
      if (_disposed) return;
      _officeLocation = location;
      if (location == null) {
        _errorMessage = 'Office information is not available yet.';
      }
    } catch (_) {
      if (!_disposed) {
        _errorMessage = 'Unable to load office information. Please try again.';
      }
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
