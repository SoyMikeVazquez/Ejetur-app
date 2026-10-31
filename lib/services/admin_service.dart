import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'driver_shift_service.dart';

class DashboardFinancialData {
  final double totalRevenue;
  final double platformCommission;
  final int totalTrips;
  final double cashTotal;
  final int cashTrips;
  final double cardTotal;
  final int cardTrips;
  final List<FlSpot> chartSpots;
  final double maxY;
  final double maxX;
  final bool isSingleDay;
  final List<String> xLabels;

  DashboardFinancialData({
    required this.totalRevenue,
    required this.platformCommission,
    required this.totalTrips,
    required this.cashTotal,
    required this.cashTrips,
    required this.cardTotal,
    required this.cardTrips,
    required this.chartSpots,
    required this.maxY,
    required this.maxX,
    required this.isSingleDay,
    required this.xLabels,
  });

  factory DashboardFinancialData.empty() {
    return DashboardFinancialData(
      totalRevenue: 0,
      platformCommission: 0,
      totalTrips: 0,
      cashTotal: 0,
      cashTrips: 0,
      cardTotal: 0,
      cardTrips: 0,
      chartSpots: [const FlSpot(0, 0)],
      maxY: 100,
      maxX: 7,
      isSingleDay: true,
      xLabels: [],
    );
  }
}

class DriverFullDetailData {
  final Map<String, dynamic> driver;
  final List<Map<String, dynamic>> allTrips;
  final double averageRating;
  final int totalRatings;
  final double totalRevenue;
  final List<Map<String, dynamic>> completedTrips;
  final List<Map<String, dynamic>> cancelledTrips;
  final double platformCommission;
  final double netEarnings;
  final double cashTotal;
  final int cashTrips;
  final double cardTotal;
  final int cardTrips;
  final bool isOnline;
  final DriverShiftStats shiftStats;

  DriverFullDetailData({
    required this.driver,
    required this.allTrips,
    required this.averageRating,
    required this.totalRatings,
    required this.totalRevenue,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.platformCommission,
    required this.netEarnings,
    required this.cashTotal,
    required this.cashTrips,
    required this.cardTotal,
    required this.cardTrips,
    required this.isOnline,
    required this.shiftStats,
  });

  factory DriverFullDetailData.empty(Map<String, dynamic> driver) {
    return DriverFullDetailData(
      driver: driver,
      allTrips: [],
      averageRating: 0.0,
      totalRatings: 0,
      totalRevenue: 0.0,
      completedTrips: [],
      cancelledTrips: [],
      platformCommission: 0.0,
      netEarnings: 0.0,
      cashTotal: 0.0,
      cashTrips: 0,
      cardTotal: 0.0,
      cardTrips: 0,
      isOnline: driver['is_online'] == true,
      shiftStats: DriverShiftStats.empty(),
    );
  }
}

class AdminStats {
  final int totalDrivers;
  final int activeDrivers;
  final int pendingApprovals;
  final int totalUsers;
  final int totalTrips;
  final double totalRevenue;
  final double platformCommission;
  final DateTime? nextCutoffDate;

  AdminStats({
    required this.totalDrivers,
    required this.activeDrivers,
    required this.pendingApprovals,
    required this.totalUsers,
    required this.totalTrips,
    required this.totalRevenue,
    required this.platformCommission,
    this.nextCutoffDate,
  });
}

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene las estadísticas globales para el Dashboard de Super Admin
  Future<AdminStats> getDashboardStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      final driversRes = await _supabase.from('conductores').select();
      final usersCount = await _supabase.from('users').count(); // Contar exacto
      // Viajes filtrados por el día de hoy
      final tripsRes = await _supabase
          .from('trips')
          .select()
          .gte('created_at', todayStart);
          
      final cutoffRes = await _supabase.from('fechas_corte').select('fecha_corte').order('fecha_corte', ascending: false).limit(1);

      final List<dynamic> drivers = (driversRes as List<dynamic>?) ?? [];
      final List<dynamic> trips = (tripsRes as List<dynamic>?) ?? [];
      
      DateTime? nextCutoff;
      if (cutoffRes != null && (cutoffRes as List).isNotEmpty) {
        final lastCutoffStr = cutoffRes[0]['fecha_corte'].toString();
        nextCutoff = DateTime.tryParse(lastCutoffStr);
      } else {
        nextCutoff = DateTime.now(); // If no cutoffs yet, fallback to now
      }

      int activeOnline = 0;
      int pending = 0;

      for (var d in drivers) {
        final isActivo = d['isActivo'] == true || d['isActivo'] == 'true';
        final aprobacion = (d['Aprobación'] ?? d['Aprobacion'] ?? d['aprobacion'] ?? '').toString().toLowerCase();
        
        if (isActivo) {
          activeOnline++;
        }
        if (aprobacion == 'pendiente') {
          pending++;
        }
      }

      double totalRevenue = 0.0;
      for (var t in trips) {
        final fare = (t['fare'] as num?)?.toDouble() ?? 0.0;
        totalRevenue += fare;
      }

      final double platformCommission = totalRevenue * 0.20;

      return AdminStats(
        totalDrivers: drivers.length,
        activeDrivers: activeOnline,
        pendingApprovals: pending,
        totalUsers: usersCount,
        totalTrips: trips.length,
        totalRevenue: totalRevenue, 
        platformCommission: platformCommission,
        nextCutoffDate: nextCutoff,
      );
    } catch (e) {
      print('Error en getDashboardStats: $e');
      return AdminStats(
        totalDrivers: 0,
        activeDrivers: 0,
        pendingApprovals: 0,
        totalUsers: 0,
        totalTrips: 0,
        totalRevenue: 0.0,
        platformCommission: 0.0,
      );
    }
  }

  /// Obtiene todos los conductores con su información completa
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    try {
      final res = await _supabase.from('conductores').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error al obtener conductores: $e');
      return [];
    }
  }

  /// Obtiene solo los conductores con estatus de aprobación Pendiente
  Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    try {
      final res = await _supabase.from('conductores').select().order('created_at', ascending: false);
      final List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(res);
      return list.where((d) {
        final ap = (d['Aprobación'] ?? d['Aprobacion'] ?? d['aprobacion'] ?? '').toString().toLowerCase();
        return ap == 'pendiente';
      }).toList();
    } catch (e) {
      print('Error al obtener conductores pendientes: $e');
      return [];
    }
  }

  /// Actualiza la aprobación de un conductor (Aprobado o Rechazado/Eliminado)
  Future<String?> setDriverApproval(String userId, {required bool approve}) async {
    try {
      if (approve) {
        await _supabase.from('conductores').update({
          'Aprobacion': 'Aprobado',
          'estatus': 'activo',
        }).eq('user_id', userId);
      } else {
        // Rechazar: Eliminar documentos del storage primero (API requerida)
        try {
          final files = await _supabase.storage.from('general').list(path: 'conductores/$userId');
          if (files.isNotEmpty) {
            final pathsToDelete = files.map((f) => 'conductores/$userId/${f.name}').toList();
            await _supabase.storage.from('general').remove(pathsToDelete);
          }
        } catch (storageError) {
          print('Nota: Error al intentar eliminar docs (pueden no existir): $storageError');
        }

        // Eliminar registros de bases de datos y Auth mediante RPC
        await _supabase.rpc('delete_driver_account', params: {'uid': userId});
      }
      return null; // null significa éxito
    } catch (e) {
      print('Error actualizando/rechazando aprobación: $e');
      return e.toString(); // Retornamos el error exacto
    }
  }

  /// Obtiene todos los usuarios registrados
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final res = await _supabase.from('users').select().order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error al obtener usuarios: $e');
      return [];
    }
  }

  /// Asigna o revoca el rol de Super Admin a un usuario
  Future<bool> toggleAdminRole(String userId, bool makeAdmin) async {
    try {
      await _supabase.from('users').update({
        'isadmin': makeAdmin,
      }).eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error cambiando rol admin: $e');
      return false;
    }
  }

  /// Obtiene los puntos de viajes para generar el mapa de calor (Heatmap)
  Future<List<LatLng>> getHeatmapPoints() async {
    try {
      final res = await _supabase.from('trips').select('origin_lat, origin_lng, destination_lat, destination_lng');
      final List<LatLng> points = [];

      for (var t in (res as List<dynamic>)) {
        final oLat = (t['origin_lat'] as num?)?.toDouble();
        final oLng = (t['origin_lng'] as num?)?.toDouble();
        if (oLat != null && oLng != null) {
          points.add(LatLng(oLat, oLng));
        }
      }

      // Puntos de densidad por defecto (CDMX / Monterrey) si no hay registros
      if (points.isEmpty) {
        points.addAll([
          const LatLng(16.7370, -92.6376),
          const LatLng(16.7350, -92.6350),
          const LatLng(16.7400, -92.6400),
          const LatLng(16.7300, -92.6300),
        ]);
      }

      return points;
    } catch (e) {
      print('Error al obtener puntos para mapa de calor: $e');
      return [
        const LatLng(16.7370, -92.6376),
        const LatLng(16.7350, -92.6350),
        const LatLng(16.7400, -92.6400),
      ];
    }
  }

  Future<void> syncTripsToFacturacion() async {
    try {
      final tripsRes = await _supabase.from('trips').select();
      final trips = (tripsRes as List<dynamic>?) ?? [];
      List<dynamic> existingFacts = [];
      try {
        final factRes = await _supabase.from('facturacion').select();
        existingFacts = (factRes as List<dynamic>?) ?? [];
      } catch (_) {}

      final Set<String> registeredTripIds = {};
      for (var f in existingFacts) {
        final datos = f['datos_adicionales'];
        if (datos != null) {
          try {
            final map = datos is Map ? datos : jsonDecode(datos.toString());
            if (map['trip_id'] != null) {
              registeredTripIds.add(map['trip_id'].toString());
            }
          } catch (_) {}
        }
      }

      for (var t in trips) {
        final tripId = (t['id'] ?? '').toString();
        final fare = (t['fare'] as num?)?.toDouble() ?? 0.0;
        final status = (t['status'] ?? '').toString().toLowerCase().trim();
        final isCompleted = status == 'completed' || status == 'completado' || status == 'finalizado';

        if ((isCompleted || fare > 0) && status != 'cancelled' && tripId.isNotEmpty && !registeredTripIds.contains(tripId)) {
          final gananciaConductor = (t['total_final'] as num?)?.toDouble() ?? (fare * 0.80);
          final comisionApp = fare * 0.20;
          final metodoPago = (t['metodo_pago'] ?? t['payment_method'] ?? 'efectivo').toString();
          final fecha = t['completed_at'] ?? t['created_at'] ?? DateTime.now().toIso8601String();
          final userId = t['user_id'] as String?;
          final driverId = t['driver_id'] as String?;

          try {
            await _supabase.from('facturacion').insert({
              'cantidad': fare,
              'metodo_pago': metodoPago,
              'fecha_servicio': fecha,
              'status': 'completado',
              'datos_adicionales': jsonEncode({
                'trip_id': tripId,
                'driver_id': driverId,
                'user_id': userId,
                'fare': fare,
                'total_final': gananciaConductor,
                'comision_app': comisionApp,
              }),
            });
            registeredTripIds.add(tripId);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<DashboardFinancialData> getDashboardFinances({
    required DateTime startDate,
    required DateTime endDate,
    String? driverId,
  }) async {
    try {
      final startFilter = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
      final endFilter = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      await syncTripsToFacturacion();

      List<dynamic> factRows = [];
      try {
        final factRes = await _supabase.from('facturacion').select();
        factRows = (factRes as List<dynamic>?) ?? [];
      } catch (_) {}

      List<dynamic> allTrips = [];
      try {
        final tripsRes = await _supabase.from('trips').select();
        allTrips = (tripsRes as List<dynamic>?) ?? [];
      } catch (_) {}

      final List<Map<String, dynamic>> financialRecords = [];
      final Set<String> processedTripIds = {};

      for (var f in factRows) {
        String? tripId;
        String? rowDriverId;
        final datos = f['datos_adicionales'];
        if (datos != null) {
          try {
            final map = datos is Map ? datos : jsonDecode(datos.toString());
            tripId = map['trip_id']?.toString();
            rowDriverId = map['driver_id']?.toString();
          } catch (_) {}
        }
        
        if (driverId != null && rowDriverId != driverId) continue;
        
        if (tripId != null && tripId.isNotEmpty) {
          processedTripIds.add(tripId);
        }

        final rawCantidad = f['cantidad'];
        final double fare = (rawCantidad is num)
            ? rawCantidad.toDouble()
            : double.tryParse(rawCantidad?.toString() ?? '0') ?? 0.0;

        financialRecords.add({
          'id': f['id'],
          'trip_id': tripId,
          'fare': fare,
          'metodo_pago': f['metodo_pago'] ?? 'efectivo',
          'date': f['fecha_servicio'] ?? f['created_at'],
          'status': f['status'] ?? 'completado',
        });
      }

      for (var t in allTrips) {
        final tDriverId = (t['driver_id'] ?? '').toString();
        if (driverId != null && tDriverId != driverId) continue;

        final tripId = (t['id'] ?? '').toString();
        if (processedTripIds.contains(tripId)) continue;

        final status = (t['status'] ?? '').toString().toLowerCase().trim();
        final isCompleted = status == 'completed' || status == 'completado' || status == 'finalizado';
        final fare = (t['fare'] as num?)?.toDouble() ?? 0.0;

        if ((isCompleted || fare > 0) && status != 'cancelled') {
          financialRecords.add({
            'id': tripId,
            'trip_id': tripId,
            'fare': fare,
            'metodo_pago': t['metodo_pago'] ?? t['payment_method'] ?? 'efectivo',
            'date': t['completed_at'] ?? t['created_at'],
            'status': status,
          });
        }
      }

      double totalRevenue = 0.0;
      double cashTotal = 0.0;
      int cashTrips = 0;
      double cardTotal = 0.0;
      int cardTrips = 0;
      int countTrips = 0;

      final diffDays = endDate.difference(startDate).inDays;
      final bool isSingleDay = diffDays <= 0 ||
          (startDate.year == endDate.year &&
              startDate.month == endDate.month &&
              startDate.day == endDate.day);

      List<double> hourlyFares = List.filled(8, 0.0);
      Map<int, double> dailyFares = {};
      final numDays = isSingleDay ? 1 : (diffDays + 1);

      if (!isSingleDay) {
        for (int i = 0; i < numDays; i++) {
          dailyFares[i] = 0.0;
        }
      }

      for (var record in financialRecords) {
        final dateStr = record['date'];
        DateTime? tripDate;
        if (dateStr != null) {
          tripDate = DateTime.tryParse(dateStr.toString())?.toLocal();
        }

        if (tripDate != null) {
          if (tripDate.isBefore(startFilter) || tripDate.isAfter(endFilter)) {
            continue;
          }
        }

        final fare = (record['fare'] as num?)?.toDouble() ?? 0.0;
        final rawMethod = (record['metodo_pago'] ?? 'efectivo')
            .toString()
            .toLowerCase()
            .trim();

        totalRevenue += fare;
        countTrips++;

        if (rawMethod.contains('efectivo') || rawMethod.contains('cash')) {
          cashTotal += fare;
          cashTrips++;
        } else {
          cardTotal += fare;
          cardTrips++;
        }

        if (tripDate != null) {
          if (isSingleDay) {
            int block = tripDate.hour ~/ 3;
            if (block >= 0 && block < 8) {
              hourlyFares[block] += fare;
            }
          } else {
            int dayIndex = tripDate.difference(startFilter).inDays;
            if (dayIndex >= 0 && dayIndex <= diffDays) {
              dailyFares[dayIndex] = (dailyFares[dayIndex] ?? 0.0) + fare;
            }
          }
        }
      }

      final double platformCommission = totalRevenue * 0.20;

      final List<FlSpot> chartSpots = [];
      double maxY = 0;
      double maxX = isSingleDay ? 7.0 : diffDays.toDouble();
      List<String> xLabels = [];

      if (isSingleDay) {
        xLabels = ['12a', '3a', '6a', '9a', '12p', '3p', '6p', '9p'];
        for (int i = 0; i < 8; i++) {
          chartSpots.add(FlSpot(i.toDouble(), hourlyFares[i]));
          if (hourlyFares[i] > maxY) maxY = hourlyFares[i];
        }
      } else {
        for (int i = 0; i <= diffDays; i++) {
          final d = startFilter.add(Duration(days: i));
          xLabels.add('${d.day}/${d.month}');
          final val = dailyFares[i] ?? 0.0;
          chartSpots.add(FlSpot(i.toDouble(), val));
          if (val > maxY) maxY = val;
        }
      }

      maxY = maxY > 0 ? maxY * 1.2 : 100.0;

      return DashboardFinancialData(
        totalRevenue: totalRevenue,
        platformCommission: platformCommission,
        totalTrips: countTrips,
        cashTotal: cashTotal,
        cashTrips: cashTrips,
        cardTotal: cardTotal,
        cardTrips: cardTrips,
        chartSpots: chartSpots.isEmpty ? [const FlSpot(0, 0)] : chartSpots,
        maxY: maxY,
        maxX: maxX,
        isSingleDay: isSingleDay,
        xLabels: xLabels,
      );
    } catch (e) {
      print('Error en getDashboardFinances: $e');
      return DashboardFinancialData.empty();
    }
  }

  Future<DriverFullDetailData> getDriverFullDetails(
    String driverId, {
    String? internalId,
    Map<String, dynamic>? initialDriver,
  }) async {
    try {
      final dRes = await _supabase.from('conductores').select().eq('user_id', driverId).maybeSingle();
      if (dRes == null && initialDriver == null) return DriverFullDetailData.empty({});
      final driverToUse = dRes ?? initialDriver!;

      final tRes = await _supabase.from('trips').select().eq('driver_id', driverId).order('created_at', ascending: false);
      final List<dynamic> tList = (tRes as List<dynamic>?) ?? [];

      final rRes = await _supabase.from('ratings').select().eq('target_id', driverId);
      final List<dynamic> rList = (rRes as List<dynamic>?) ?? [];

      double totalRating = 0;
      int count = 0;
      for (var r in rList) {
        final rate = (r['rating'] as num?)?.toDouble();
        if (rate != null) {
          totalRating += rate;
          count++;
        }
      }
      final double avgRating = count > 0 ? (totalRating / count) : 0.0;

      List<Map<String, dynamic>> allTrips = tList.map((e) => e as Map<String, dynamic>).toList();
      List<Map<String, dynamic>> completedTrips = [];
      List<Map<String, dynamic>> cancelledTrips = [];

      double totalRevenue = 0.0;
      double cashTotal = 0.0;
      int cashTrips = 0;
      double cardTotal = 0.0;
      int cardTrips = 0;

      for (var trip in allTrips) {
        final status = (trip['status'] ?? '').toString().toLowerCase().trim();
        final isCompleted = status == 'completed' || status == 'completado' || status == 'finalizado';
        if (isCompleted) {
          completedTrips.add(trip);
          final fare = (trip['fare'] as num?)?.toDouble() ?? 0.0;
          totalRevenue += fare;
          final method = (trip['metodo_pago'] ?? trip['payment_method'] ?? '').toString().toLowerCase();
          if (method.contains('efectivo') || method.contains('cash')) {
            cashTotal += fare;
            cashTrips++;
          } else {
            cardTotal += fare;
            cardTrips++;
          }
        } else if (status == 'cancelled' || status == 'cancelado') {
          cancelledTrips.add(trip);
        }
      }

      final platformCommission = totalRevenue * 0.20;
      final netEarnings = totalRevenue - platformCommission;

      final bool isOnline = driverToUse['is_online'] == true;
      DriverShiftStats shiftStats = DriverShiftStats.empty();
      try {
        final shiftService = DriverShiftService();
        shiftStats = await shiftService.getDriverShiftStats(driverId);
      } catch (e) {
        print('Error getting shift stats in AdminService: $e');
      }

      return DriverFullDetailData(
        driver: driverToUse,
        allTrips: allTrips,
        averageRating: avgRating,
        totalRatings: count,
        totalRevenue: totalRevenue,
        completedTrips: completedTrips,
        cancelledTrips: cancelledTrips,
        platformCommission: platformCommission,
        netEarnings: netEarnings,
        cashTotal: cashTotal,
        cashTrips: cashTrips,
        cardTotal: cardTotal,
        cardTrips: cardTrips,
        isOnline: isOnline,
        shiftStats: shiftStats,
      );
    } catch (e) {
      print('Error en getDriverFullDetails: $e');
      return DriverFullDetailData.empty(initialDriver ?? {});
    }
  }

  Future<bool> setDriverOnlineStatus(String driverId, bool isOnline) async {
    try {
      await _supabase.from('conductores').update({
        'is_online': isOnline,
        if (!isOnline) 'is_activo': false,
      }).eq('user_id', driverId);
      return true;
    } catch (e) {
      print('Error al actualizar estado online del conductor: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDynamicPricingZones() async {
    try {
      final response = await _supabase.from('zonas_tarifa_dinamica').select().order('created_at', ascending: false);
      return (response as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('Error en getDynamicPricingZones: $e');
      return [];
    }
  }

  Future<String?> addDynamicPricingZone({
    required String name,
    required double lat,
    required double lng,
    required double radiusKm,
    required double percentageIncrease,
  }) async {
    try {
      await _supabase.from('zonas_tarifa_dinamica').insert({
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
        'percentage_increase': percentageIncrease,
        'is_active': true,
      });
      return null; // Éxito
    } catch (e) {
      print('Error en addDynamicPricingZone: $e');
      return e.toString();
    }
  }

  Future<bool> toggleDynamicPricingZone(String id, bool isActive) async {
    try {
      await _supabase.from('zonas_tarifa_dinamica').update({'is_active': isActive}).eq('id', id);
      return true;
    } catch (e) {
      print('Error en toggleDynamicPricingZone: $e');
      return false;
    }
  }

  Future<bool> deleteDynamicPricingZone(String id) async {
    try {
      await _supabase.from('zonas_tarifa_dinamica').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error en deleteDynamicPricingZone: $e');
      return false;
    }
  }

  // ==============================================
  // TARIFAS POR DENSIDAD (MAPA DE CALOR)
  // ==============================================

  Future<List<Map<String, dynamic>>> getDensityPricing() async {
    try {
      final res = await _supabase.from('tarifas_mapas_calor_perse').select().order('Porcentaje', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('Error al obtener tarifas de densidad: $e');
      return [];
    }
  }

  Future<void> updateDensityPricing(int id, num porcentaje) async {
    try {
      await _supabase.from('tarifas_mapas_calor_perse').update({'Porcentaje': porcentaje}).eq('id', id);
    } catch (e) {
      print('Error al actualizar tarifa de densidad: $e');
      throw e;
    }
  }

  // ==============================================
  // USUARIOS REFERIDOS POR CONDUCTOR
  // ==============================================

  Future<List<Map<String, dynamic>>> getDriverReferrals({
    String? driverPhone,
    required String driverName,
    String? driverFullName,
    String? driverUserId,
    String? driverId,
  }) async {
    try {
      final candidateNames = <String>{};
      final cleanName = driverName.trim().toLowerCase();
      if (cleanName.isNotEmpty) candidateNames.add(cleanName);
      if (driverFullName != null && driverFullName.trim().isNotEmpty) {
        candidateNames.add(driverFullName.trim().toLowerCase());
      }
      if (driverUserId != null && driverUserId.trim().isNotEmpty) {
        candidateNames.add(driverUserId.trim().toLowerCase());
      }
      if (driverId != null && driverId.trim().isNotEmpty) {
        candidateNames.add(driverId.trim().toLowerCase());
      }

      final cleanDriverPhone = (driverPhone ?? '').replaceAll(RegExp(r'\D'), '');
      final candidatePhones = <String>{};
      if (cleanDriverPhone.isNotEmpty) {
        candidatePhones.add(cleanDriverPhone);
        if (cleanDriverPhone.startsWith('52') && cleanDriverPhone.length > 10) {
          candidatePhones.add(cleanDriverPhone.substring(2));
        }
        if (cleanDriverPhone.length == 10) {
          candidatePhones.add('52$cleanDriverPhone');
        }
      }

      final res = await _supabase
          .from('users')
          .select('id, user_id, nombre, correo, telefono, imagen_perfil, fotodeperfil, referido, time_referido, usuario_activado, comision_referido, created_at')
          .not('referido', 'is', null)
          .order('time_referido', ascending: false);

      final list = List<Map<String, dynamic>>.from(res as List);
      final filtered = list.where((u) {
        final ref = (u['referido'] ?? '').toString().trim().toLowerCase();
        if (ref.isEmpty) return false;
        final cleanRefDigits = ref.replaceAll(RegExp(r'\D'), '');

        // 1. Coincidencia por teléfono del conductor
        if (candidatePhones.isNotEmpty && cleanRefDigits.isNotEmpty) {
          if (candidatePhones.any((p) => cleanRefDigits == p || cleanRefDigits.endsWith(p) || p.endsWith(cleanRefDigits))) {
            return true;
          }
        }

        // 2. Coincidencia por nombre / ID para compatibilidad
        return candidateNames.any((name) => ref == name || ref.contains(name) || name.contains(ref));
      }).toList();

      return filtered;
    } catch (e) {
      print('Error al obtener referidos del conductor: $e');
      return [];
    }
  }
}