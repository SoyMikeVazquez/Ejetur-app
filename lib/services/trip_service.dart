import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import 'package:latlong2/latlong.dart';
import 'rating_service.dart';
import 'resend_service.dart';
import 'geofence_service.dart';

class TripService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Helper para notificar a pasajero y conductor sobre cambios de estatus
  Future<void> notifyTripStatusChange(String tripId, String status) async {
    try {
      final trip = await _client.from('trips').select().eq('id', tripId).maybeSingle();
      if (trip == null) return;
      
      final String? userId = trip['user_id'];
      final String? driverId = trip['driver_id'];
      
      String passengerName = 'Pasajero';
      String passengerEmail = '';
      if (userId != null) {
        final userRes = await _client.from('users').select().eq('user_id', userId).maybeSingle();
        if (userRes != null) {
          passengerName = userRes['nombre'] ?? 'Pasajero';
          passengerEmail = userRes['correo'] ?? '';
        }
      }

      String driverName = 'Conductor';
      String driverEmail = '';
      if (driverId != null) {
        final driverRes = await _client.from('conductores').select().eq('user_id', driverId).maybeSingle();
        final dRes = driverRes ?? await _client.from('conductores').select().eq('id', driverId).maybeSingle();
        if (dRes != null) {
          driverName = dRes['nombre_completo'] ?? dRes['nombre'] ?? 'Conductor';
          driverEmail = dRes['correo'] ?? '';
        }
      }

      if (passengerEmail.isNotEmpty) {
        ResendService.notifyPassengerTripStatus(
          passengerEmail: passengerEmail,
          passengerName: passengerName,
          driverName: driverName,
          status: status,
        ).then((_) => print('Email a pasajero enviado')).catchError((e) => print('Error email pasajero: $e'));
      }

      if (driverEmail.isNotEmpty && (status == 'aceptado' || status == 'accepted' || status == 'cancelado' || status == 'cancelled')) {
        ResendService.notifyDriverTripStatus(
          driverEmail: driverEmail,
          driverName: driverName,
          passengerName: passengerName,
          status: status,
        ).then((_) => print('Email a conductor enviado')).catchError((e) => print('Error email conductor: $e'));
      }
    } catch (e) {
      print('Error en notifyTripStatusChange: $e');
    }
  }

  /// Crear un nuevo viaje (Intento 1: estado pending)
  Future<Trip?> createTrip(Trip trip) async {
    // 0. Validar geofence (solo Chiapas a menos que tenga permiso especial)
    if (trip.originLat != null && trip.originLng != null) {
      final canRequest = await GeofenceService.canRequestTrip(
        userId: trip.userId,
        origin: LatLng(trip.originLat!, trip.originLng!),
      );
      if (!canRequest) {
        print('Creación de viaje bloqueada: El origen está fuera del estado de Chiapas y el usuario no tiene permiso especial.');
        return null;
      }
    }

    // 1. Validar que el usuario no tenga ya un viaje activo
    final activeTrip = await getActiveTripForPassenger(trip.userId);
    if (activeTrip != null) {
      print('El usuario ya tiene un viaje activo. No se puede crear otro.');
      return activeTrip; // Retornamos el viaje activo existente para que la UI lo retome
    }

    final payload = trip.toJson();
    payload.remove('id'); // Supabase genera el UUID
    payload.remove('created_at');
    payload.removeWhere((key, value) => value == null);

    // Intento 1: Inserción completa
    try {
      final response = await _client
          .from('trips')
          .insert(payload)
          .select()
          .single();
          
      return Trip.fromJson(response);
    } catch (e) {
      print('Error creando viaje (Intento 1): $e');
    }

    // Intento 2: Si 'pending' falla por restricción CHECK antigua (in_progress, completed, cancelled)
    try {
      final fallbackPayload = Map<String, dynamic>.from(payload);
      fallbackPayload['status'] = 'in_progress';
      final response = await _client
          .from('trips')
          .insert(fallbackPayload)
          .select()
          .single();
          
      return Trip.fromJson(response);
    } catch (e2) {
      print('Error creando viaje (Intento 2 - in_progress): $e2');
    }

    // Intento 3: Columnas esenciales mínimas (user_id, origin_address, destination_address)
    try {
      final response = await _client
          .from('trips')
          .insert({
            'user_id': trip.userId,
            'origin_address': trip.originAddress,
            'destination_address': trip.destinationAddress,
            'fare': trip.fare ?? 0.0,
            'distance_km': trip.distanceKm ?? 0.0,
          })
          .select()
          .single();

      return Trip.fromJson(response);
    } catch (e3) {
      print('Error creando viaje (Intento 3 - mínimo): $e3');
      return null;
    }
  }

  /// Obtiene el historial de viajes de un usuario (pasajero)
  Future<List<Trip>> getUserTrips(String userId) async {
    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo viajes del usuario: $e');
      return [];
    }
  }

  /// Stream en tiempo real de viajes disponibles (en espera)
  Stream<List<Trip>> streamPendingTrips() {
    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Trip.fromJson(json)).toList());
  }

  /// Obtiene la información pública del conductor (nombre y foto)
  Future<Map<String, String?>> getDriverPublicInfo(String driverId) async {
    try {
      String? name;
      String? photo;

      // 1. Intentar desde public.conductores por user_id
      final driverResp = await _client
          .from('conductores')
          .select('nombre, nombre_completo, imagen_perfil')
          .eq('user_id', driverId)
          .maybeSingle();

      if (driverResp != null) {
        final nComp = driverResp['nombre_completo'] as String?;
        final nSimple = driverResp['nombre'] as String?;
        name = (nComp != null && nComp.trim().isNotEmpty) ? nComp.trim() : nSimple?.trim();
        photo = driverResp['imagen_perfil'] as String?;
      }

      // 2. Si no se encontró por user_id, intentar por id
      if (name == null || name.isEmpty) {
        final driverRespById = await _client
            .from('conductores')
            .select('nombre, nombre_completo, imagen_perfil')
            .eq('id', driverId)
            .maybeSingle();
        if (driverRespById != null) {
          final nComp = driverRespById['nombre_completo'] as String?;
          final nSimple = driverRespById['nombre'] as String?;
          name = (nComp != null && nComp.trim().isNotEmpty) ? nComp.trim() : nSimple?.trim();
          photo ??= driverRespById['imagen_perfil'] as String?;
        }
      }

      // 3. Si no tiene nombre o foto, buscar en public.users
      if (name == null || name.isEmpty || photo == null || photo.isEmpty) {
        final userResp = await _client
            .from('users')
            .select('nombre, imagen_perfil, fotodeperfil')
            .eq('user_id', driverId)
            .maybeSingle();

        if (userResp != null) {
          name ??= (userResp['nombre'] as String?)?.trim();
          photo ??= (userResp['imagen_perfil'] as String?) ?? (userResp['fotodeperfil'] as String?);
        }
      }

      // 4. Si aún no tiene nombre y coincide con el currentUser actual
      final currentAuth = _client.auth.currentUser;
      if (currentAuth != null && currentAuth.id == driverId) {
        final meta = currentAuth.userMetadata;
        if (meta != null) {
          name ??= (meta['name'] ?? meta['full_name'] ?? meta['nombre'])?.toString().trim();
          photo ??= (meta['avatar_url'] ?? meta['picture'])?.toString();
        }
      }

      return {
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : 'Conductor',
        'photo': photo,
      };
    } catch (e) {
      print('Error al obtener información pública del conductor: $e');
      return {'name': null, 'photo': null};
    }
  }

  /// Obtiene la información pública del pasajero (nombre, teléfono, foto y calificación promedio)
  Future<Map<String, dynamic>> getPassengerPublicInfo(String passengerUserId) async {
    try {
      String? name;
      String? phone;
      String? photo;

      // 1. Consultar en public.users
      final userResp = await _client
          .from('users')
          .select('nombre, telefono, imagen_perfil, fotodeperfil')
          .eq('user_id', passengerUserId)
          .maybeSingle();

      if (userResp != null) {
        name = userResp['nombre'] as String?;
        phone = userResp['telefono'] as String?;
        photo = (userResp['imagen_perfil'] as String?) ?? (userResp['fotodeperfil'] as String?);
      }

      // 2. Obtener calificación promedio del pasajero
      final ratingService = RatingService();
      final stats = await ratingService.getUserRatingStats(passengerUserId, role: 'passenger');
      final double avgRating = stats['average'] as double;
      final int totalRatings = stats['total'] as int;

      return {
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : 'Pasajero',
        'phone': phone,
        'photo': photo,
        'rating': avgRating,
        'totalRatings': totalRatings,
      };
    } catch (e) {
      print('Error al obtener info del pasajero: $e');
      return {
        'name': 'Pasajero',
        'phone': null,
        'photo': null,
        'rating': 5.0,
        'totalRatings': 0,
      };
    }
  }

  /// Conductor acepta un viaje
  Future<bool> acceptTrip(String tripId, String driverId) async {
    try {
      final driverInfo = await getDriverPublicInfo(driverId);
      final updateData = <String, dynamic>{
        'driver_id': driverId,
        'status': 'accepted',
      };
      if (driverInfo['name'] != null && driverInfo['name']!.isNotEmpty) {
        updateData['name_driver'] = driverInfo['name'];
      }
      if (driverInfo['photo'] != null && driverInfo['photo']!.isNotEmpty) {
        updateData['photo_driver'] = driverInfo['photo'];
      }

      final response = await _client.from('trips').update(updateData)
      .eq('id', tripId)
      .eq('status', 'pending')
      .select()
      .maybeSingle();

      if (response == null) {
        print('El viaje ya no está pendiente o fue tomado por otro conductor.');
        return false;
      }
      
      // Notificar a ambos por correo
      notifyTripStatusChange(tripId, 'aceptado');
      
      return true;
    } catch (e) {
      print('Error aceptando viaje: $e');
      return false;
    }
  }

  /// Obtener el viaje activo del conductor, si existe
  Future<Trip?> getActiveTrip(String driverId) async {
    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .inFilter('status', const ['accepted', 'arrived', 'in_progress'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        return Trip.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error obteniendo viaje activo: $e');
      return null;
    }
  }

  /// Stream de un viaje específico por ID para actualizaciones en tiempo real
  Stream<Trip?> streamTrip(String tripId) {
    return _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .map((data) => data.isEmpty ? null : Trip.fromJson(data.first));
  }

  /// Obtener el viaje activo o pendiente del pasajero, si existe
  Future<Trip?> getActiveTripForPassenger(String userId) async {
    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('user_id', userId)
          .inFilter('status', const ['pending', 'accepted', 'arrived', 'in_progress'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      if (response != null) {
        return Trip.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error obteniendo viaje activo del pasajero: $e');
      return null;
    }
  }

  /// Actualizar el estado del viaje (ej: arrived, in_progress)
  Future<bool> updateTripStatus(String tripId, String newStatus, {int? codigo}) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
      };
      
      if (newStatus == 'arrived') {
        updateData['arrived_at'] = DateTime.now().toUtc().toIso8601String();
        // Generar código de 5 dígitos para verificación (estilo Uber) si no viene provisto
        final pinCode = codigo ?? (10000 + Random().nextInt(90000));
        updateData['codigo'] = pinCode;
      } else if (codigo != null) {
        updateData['codigo'] = codigo;
      }

      await _client.from('trips').update(updateData).eq('id', tripId);
      
      // Notificar cambio de estado
      notifyTripStatusChange(tripId, newStatus == 'arrived' ? 'en camino' : newStatus);
      
      return true;
    } catch (e) {
      print('Error actualizando estado del viaje: $e');
      return false;
    }
  }

  /// Conductor completa un viaje y se registra el cobro
  Future<bool> completeTrip(String tripId, double fare, {String? nameDriver, String? photoDriver}) async {
    try {
      final double gananciaConductor = fare * 0.80; // 80% del total

      String? finalName = nameDriver;
      String? finalPhoto = photoDriver;

      Map<String, dynamic>? currentTrip;
      try {
        currentTrip = await _client.from('trips').select().eq('id', tripId).maybeSingle();
      } catch (_) {}

      final String? driverId = currentTrip?['driver_id'] as String? ?? _client.auth.currentUser?.id;
      final String? userId = currentTrip?['user_id'] as String?;
      final String metodoPago = (currentTrip?['metodo_pago'] ?? currentTrip?['payment_method'] ?? 'efectivo').toString();

      if (finalName == null || finalName.isEmpty || finalPhoto == null || finalPhoto.isEmpty) {
        if (driverId != null) {
          try {
            final driverInfo = await getDriverPublicInfo(driverId);
            finalName ??= driverInfo['name'];
            finalPhoto ??= driverInfo['photo'];
          } catch (_) {}
        }
      }

      await _client.from('trips').update({
        'status': 'completed',
        'fare': fare,
        'total_final': gananciaConductor, // Guarda directamente el ingreso del conductor
        'completed_at': DateTime.now().toIso8601String(),
        if (finalName != null && finalName.isNotEmpty) 'name_driver': finalName,
        if (finalPhoto != null && finalPhoto.isNotEmpty) 'photo_driver': finalPhoto,
      }).eq('id', tripId);

      // Regla de Facturación TaxiSeguro: al finalizar el viaje, se mandan los detalles a los row de facturación
      try {
        String? passengerEmail;
        String? passengerPhone;
        String? passengerName;
        if (userId != null && userId.isNotEmpty) {
          try {
            final userRes = await _client.from('users').select().eq('user_id', userId).maybeSingle();
            if (userRes != null) {
              passengerEmail = userRes['correo'] as String?;
              passengerPhone = userRes['telefono'] as String?;
              passengerName = userRes['nombre'] as String?;
            }

            final bool wasAlreadyActivated = userRes != null && userRes['usuario_activado'] == true;
            final bool hasReferido = userRes != null &&
                userRes['referido'] != null &&
                userRes['referido'].toString().trim().isNotEmpty;

            final Map<String, dynamic> updateUserData = {
              'usuario_activado': true,
            };

            // Regla del Sistema de Referidos:
            // Al completar su PRIMER viaje, tomamos el 20% del monto a pagar (fare)
            // y lo guardamos en la columna comision_referido de la tabla users.
            if (hasReferido && !wasAlreadyActivated) {
              final double comisionReferido = fare * 0.20;
              updateUserData['comision_referido'] = comisionReferido;
              print('Sistema de Referidos: Comisión de \$${comisionReferido.toStringAsFixed(2)} asignada por 1er viaje de usuario $userId (Monto: \$$fare) para el conductor: ${userRes['referido']}');
            }

            await _client.from('users').update(updateUserData).eq('user_id', userId);
          } catch (activateError) {
            print('Error activando usuario o calculando comisión de referido: $activateError');
          }
        }

        final double comisionApp = fare * 0.20; // 20% TaxiSeguro

        await _client.from('facturacion').insert({
          'cantidad': fare,
          'metodo_pago': metodoPago,
          'fecha_servicio': DateTime.now().toIso8601String(),
          'status': 'completado',
          if (passengerEmail != null && passengerEmail.isNotEmpty) 'email': passengerEmail,
          if (passengerPhone != null && passengerPhone.isNotEmpty) 'telefono': passengerPhone,
          if (passengerName != null && passengerName.isNotEmpty) 'razon_social': passengerName,
          'datos_adicionales': jsonEncode({
            'trip_id': tripId,
            'driver_id': driverId,
            'user_id': userId,
            'fare': fare,
            'total_final': gananciaConductor,
            'comision_app': comisionApp,
            'ganancia_conductor': gananciaConductor,
            'origin_address': currentTrip?['origin_address'],
            'destination_address': currentTrip?['destination_address'],
            'distance_km': currentTrip?['distance_km'],
            'name_driver': finalName,
          }),
        });
        print('Detalle de facturación registrado correctamente en la tabla facturación para el viaje: $tripId');
      } catch (factErr) {
        print('Aviso: no se pudo registrar en tabla facturacion: $factErr');
      }

      // Notificar completado
      notifyTripStatusChange(tripId, 'finalizado');

      return true;
    } catch (e) {
      print('Error completando viaje: $e');
      return false;
    }
  }

  /// Cancelar un viaje
  Future<bool> cancelTrip(String tripId, {String? cancelReason, String? nameDriver, String? photoDriver}) async {
    try {
      String? finalName = nameDriver;
      String? finalPhoto = photoDriver;

      if (finalName == null || finalName.isEmpty || finalPhoto == null || finalPhoto.isEmpty) {
        try {
          final currentTrip = await _client.from('trips').select('driver_id').eq('id', tripId).maybeSingle();
          final String? driverId = currentTrip?['driver_id'] as String? ?? _client.auth.currentUser?.id;
          if (driverId != null) {
            final driverInfo = await getDriverPublicInfo(driverId);
            finalName ??= driverInfo['name'];
            finalPhoto ??= driverInfo['photo'];
          }
        } catch (_) {}
      }

      await _client.from('trips').update({
        'status': 'cancelled',
        'cancel_reason': ?cancelReason,
        if (finalName != null && finalName.isNotEmpty) 'name_driver': finalName,
        if (finalPhoto != null && finalPhoto.isNotEmpty) 'photo_driver': finalPhoto,
      }).eq('id', tripId);
      
      // Notificar cancelación
      notifyTripStatusChange(tripId, 'cancelado');
      
      return true;
    } catch (e) {
      print('Error cancelando viaje: $e');
      return false;
    }
  }

  /// Obtiene las ganancias del día actual para un conductor
  Future<double> getDriverEarningsToday(String driverId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await _client
          .from('trips')
          .select('fare')
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .gte('completed_at', startOfDay);

      double total = 0.0;
      for (final row in response as List) {
        if (row['fare'] != null) {
          total += (row['fare'] as num).toDouble();
        }
      }
      return total;
    } catch (e) {
      print('Error calculando ganancias de hoy: $e');
      return 0.0;
    }
  }

  /// Obtiene los últimos viajes completados por el conductor
  Future<List<Trip>> getDriverCompletedTrips(String driverId) async {
    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(10);

      return (response as List).map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo viajes completados: $e');
      return [];
    }
  }

  /// Obtiene todos los viajes completados por el conductor para historial financiero
  Future<List<Trip>> getAllDriverCompletedTrips(String driverId) async {
    try {
      final response = await _client
          .from('trips')
          .select()
          .eq('driver_id', driverId)
          .eq('status', 'completed')
          .order('completed_at', ascending: false);

      return (response as List).map((json) => Trip.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo todos los viajes completados: $e');
      return [];
    }
  }
}
