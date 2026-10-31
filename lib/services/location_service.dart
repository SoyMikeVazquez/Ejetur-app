import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  /// Obtiene la ubicación GPS real actual del dispositivo
  Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Verificar si los servicios de ubicación están activos
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Los servicios de geolocalización están desactivados.');
        return null;
      }

      // Verificar y solicitar permisos de ubicación
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Permisos de geolocalización denegados.');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('Permisos denegados permanentemente.');
        return null;
      }
    } catch (e) {
      print('Error comprobando permisos de geolocalización (probablemente macOS): $e');
      // No devolvemos null, dejamos que continúe al fallback del try-catch de abajo
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Damos más tiempo para obtener GPS real
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error al obtener posición GPS (posible simulador): $e');
      // Fallback a Tuxtla Gutiérrez, Chiapas si el GPS falla o tarda mucho (muy útil en simuladores)
      return const LatLng(16.7569, -93.1292);
    }
  }

  /// Escucha los cambios de posición del dispositivo en tiempo real
  Stream<LatLng> getLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map(
      (position) => LatLng(position.latitude, position.longitude),
    );
  }
}
