import 'package:campusfind_flutter/features/drop_off/services/maps_launcher_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test(
    'launches a directions URI with the supplied coordinates externally',
    () async {
      Uri? launchedUri;
      LaunchMode? launchedMode;
      final service = MapsLauncherService(
        launcher: (uri, {required mode}) async {
          launchedUri = uri;
          launchedMode = mode;
          return true;
        },
      );
      expect(
        await service.openDirections(latitude: 12.34, longitude: -56.78),
        isTrue,
      );
      expect(launchedUri?.scheme, 'https');
      expect(launchedUri?.host, 'www.google.com');
      expect(launchedUri?.path, '/maps/dir/');
      expect(launchedUri?.queryParameters, {
        'api': '1',
        'destination': '12.34,-56.78',
      });
      expect(launchedMode, LaunchMode.externalApplication);
    },
  );

  test('returns false when the platform cannot launch the URL', () async {
    final service = MapsLauncherService(
      launcher: (_, {required mode}) async => false,
    );
    expect(await service.openDirections(latitude: 4, longitude: -74), isFalse);
  });

  test('returns false when the platform throws', () async {
    final service = MapsLauncherService(
      launcher: (_, {required mode}) async {
        throw PlatformException(code: 'launch_failed');
      },
    );
    expect(await service.openDirections(latitude: 4, longitude: -74), isFalse);
  });
}
