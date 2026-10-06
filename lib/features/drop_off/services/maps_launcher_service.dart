import 'package:url_launcher/url_launcher.dart';

typedef MapsUrlLauncher = Future<bool> Function(
  Uri uri, {
  required LaunchMode mode,
});

class MapsLauncherService {
  const MapsLauncherService({this._launcher = launchUrl});

  final MapsUrlLauncher _launcher;

  Future<bool> openDirections({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
    });
    try {
      return await _launcher(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
