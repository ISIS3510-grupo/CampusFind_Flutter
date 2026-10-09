import 'package:connectivity_plus/connectivity_plus.dart';

// Tells the app whether the device has a network connection.
abstract class ConnectivityService {
  Future<bool> isOnline();

  // Emits true when the connection comes back and false when it is lost.
  Stream<bool> get onlineChanges;
}

class DeviceConnectivityService implements ConnectivityService {
  DeviceConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> isOnline() async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();
}
