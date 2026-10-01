
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Obtiene la ubicación GPS actual del dispositivo verificando permisos
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Verificar si los servicios de localización están activados en el teléfono
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Los servicios de ubicación están desactivados.');
    }

    // 2. Verificar los permisos de la aplicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Los permisos de ubicación fueron denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Los permisos de ubicación están denegados permanentemente. Habilítalos en los ajustes del teléfono.',
      );
    }

    // 3. Obtener y retornar la posición actual
    return await Geolocator.getCurrentPosition(
      // ignore: deprecated_member_use
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}

