import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeofenceService {
  /// Centro por defecto en Chiapas (Tuxtla Gutiérrez)
  static const LatLng defaultChiapasCenter = LatLng(16.7569, -93.1292);

  // Bounding Box del Estado de Chiapas para descarte rápido en O(1)
  static const double minLat = 14.50;
  static const double maxLat = 18.05;
  static const double minLng = -94.25;
  static const double maxLng = -90.30;

  // Polígono simplificado del perímetro oficial del estado de Chiapas (México)
  static const List<LatLng> _chiapasPolygon = [
    LatLng(16.4618, -94.1392),
    LatLng(16.2759, -94.0330),
    LatLng(16.1791, -94.1096),
    LatLng(16.0221, -94.0360),
    LatLng(15.8965, -93.7490),
    LatLng(15.5911, -93.3323),
    LatLng(14.5311, -92.2283),
    LatLng(14.6587, -92.1472),
    LatLng(14.8283, -92.1848),
    LatLng(14.8916, -92.1362),
    LatLng(14.9894, -92.1505),
    LatLng(15.0708, -92.0593),
    LatLng(15.2606, -92.2105),
    LatLng(16.0739, -91.7316),
    LatLng(16.0738, -90.4422),
    LatLng(16.2495, -90.4562),
    LatLng(16.3396, -90.3827),
    LatLng(16.3620, -90.4121),
    LatLng(16.3660, -90.3715),
    LatLng(16.4159, -90.3948),
    LatLng(16.4234, -90.4865),
    LatLng(16.4610, -90.4800),
    LatLng(16.4779, -90.6314),
    LatLng(16.5780, -90.6263),
    LatLng(16.5818, -90.6671),
    LatLng(16.7251, -90.7122),
    LatLng(16.8219, -90.9218),
    LatLng(16.9015, -90.9650),
    LatLng(16.8631, -90.9878),
    LatLng(16.9029, -91.0656),
    LatLng(17.1079, -91.2669),
    LatLng(17.1792, -91.2779),
    LatLng(17.1589, -91.3467),
    LatLng(17.2166, -91.4274),
    LatLng(17.3018, -91.4255),
    LatLng(17.3128, -91.3835),
    LatLng(17.3741, -91.4198),
    LatLng(17.4673, -91.7000),
    LatLng(17.5346, -91.6343),
    LatLng(17.6762, -91.6547),
    LatLng(17.7377, -91.8307),
    LatLng(17.7825, -91.7823),
    LatLng(17.9004, -91.8125),
    LatLng(17.8633, -91.9484),
    LatLng(17.9074, -91.9403),
    LatLng(17.9433, -91.9999),
    LatLng(17.8905, -92.0034),
    LatLng(17.8147, -92.1466),
    LatLng(17.7661, -92.1308),
    LatLng(17.7766, -92.1945),
    LatLng(17.6923, -92.2746),
    LatLng(17.7121, -92.3373),
    LatLng(17.6179, -92.3507),
    LatLng(17.5496, -92.5714),
    LatLng(17.4567, -92.6682),
    LatLng(17.3785, -92.6788),
    LatLng(17.3433, -92.7542),
    LatLng(17.4175, -92.7858),
    LatLng(17.4112, -92.8543),
    LatLng(17.4809, -92.8316),
    LatLng(17.4827, -92.9486),
    LatLng(17.6097, -93.0408),
    LatLng(17.8254, -93.0253),
    LatLng(17.8222, -93.1157),
    LatLng(17.8976, -93.0914),
    LatLng(17.9853, -93.2783),
    LatLng(17.9303, -93.3409),
    LatLng(17.7981, -93.3406),
    LatLng(17.7832, -93.3809),
    LatLng(17.7671, -93.3491),
    LatLng(17.7734, -93.3905),
    LatLng(17.6480, -93.3563),
    LatLng(17.5460, -93.4876),
    LatLng(17.4428, -93.5138),
    LatLng(17.2563, -93.6627),
    LatLng(17.2419, -93.7983),
    LatLng(17.1637, -93.8609),
    LatLng(16.4618, -94.1392),
  ];

  /// Verifica si una coordenada geográfica se encuentra dentro del estado de Chiapas.
  /// Ejecuta algoritmo Ray-Casting (Point in Polygon) en O(N) local en microsegundos.
  static bool isWithinChiapas(LatLng point) {
    final lat = point.latitude;
    final lng = point.longitude;

    // 1. Descarte rápido por Bounding Box
    if (lat < minLat || lat > maxLat || lng < minLng || lng > maxLng) {
      return false;
    }

    // 2. Comprobación precisa del polígono
    bool inside = false;
    final int n = _chiapasPolygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = _chiapasPolygon[i].longitude;
      final yi = _chiapasPolygon[i].latitude;
      final xj = _chiapasPolygon[j].longitude;
      final yj = _chiapasPolygon[j].latitude;

      final bool intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
      if (intersect) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Hook para validar si el usuario tiene un permiso especial para solicitar servicios fuera de Chiapas.
  /// Preparado para implementación posterior: si en Supabase se agrega una columna como
  /// 'has_special_location_permission' o 'bypass_geofence', se detectará automáticamente.
  static Future<bool> hasSpecialLocationPermission(String userId) async {
    try {
      final userDoc = await Supabase.instance.client
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (userDoc == null) return false;

      // Si existe algún flag especial en la base de datos:
      final hasPerm = userDoc['has_special_location_permission'] == true ||
          userDoc['bypass_geofence'] == true ||
          userDoc['permiso_especial_ubicacion'] == true;

      return hasPerm;
    } catch (e) {
      // Si la columna no existe o hay algún error de red, deniega por defecto de forma segura
      print('Aviso: Comprobación de permiso especial de ubicación: $e');
      return false;
    }
  }

  /// Regla de negocio principal:
  /// Retorna `true` si el servicio se puede solicitar (está dentro de Chiapas O el usuario cuenta con permiso especial).
  static Future<bool> canRequestTrip({
    required String userId,
    required LatLng origin,
  }) async {
    // Si el punto de recogida está en Chiapas, se permite a cualquier usuario
    if (isWithinChiapas(origin)) {
      return true;
    }

    // Si está fuera de Chiapas, verificar si el usuario tiene permiso especial
    final bool hasPermission = await hasSpecialLocationPermission(userId);
    return hasPermission;
  }
}
