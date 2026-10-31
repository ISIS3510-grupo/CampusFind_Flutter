import 'package:geolocator/geolocator.dart';

import '../models/campus_locations.dart';

class LocationService {
  // gives the GPS location stored in onResult or null if it was not available
  void getCurrentLocation(void Function(Position? position) onResult) {
    // this method encapsulates GPS access (permissions, read position..)
    Geolocator.isLocationServiceEnabled()
        .then((enabled) {
          //.then makes the function's flow wait for the variable for executing
          if (!enabled) {
            onResult(null);
            return;
          }
          Geolocator.checkPermission()
              .then((permission) {
                //in this case .then allows the step by step jerarchy
                if (permission == LocationPermission.denied) {
                  Geolocator.requestPermission()
                      .then((granted) => _readPosition(granted, onResult))
                      .catchError((Object e) {
                        onResult(null);
                      });
                } else {
                  _readPosition(permission, onResult);
                }
              })
              .catchError((Object e) {
                onResult(null);
              });
        })
        .catchError((Object e) {
          onResult(null);
        });
  }

  void _readPosition(
    LocationPermission permission,
    void Function(Position? position) onResult,
  ) {
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      onResult(null);
      return;
    }
    Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        )
        .then((position) {
          onResult(position);
        })
        .catchError((Object e) {
          onResult(null);
        });
  }

  // Returns the organized buildings (closer to far)
  // (distance: streight line).
  List<CampusLocation> sortByDistance({
    required double userLat,
    required double userLng,
    required List<CampusLocation> locations,
  }) {
    final sorted = List<CampusLocation>.from(locations);
    sorted.sort(
      (a, b) => a
          .distanceTo(userLat, userLng)
          .compareTo(b.distanceTo(userLat, userLng)),
    );
    return sorted; // at the end it returns a sorted list of the organized buildings
  }
}
