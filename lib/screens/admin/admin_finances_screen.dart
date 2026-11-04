import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/trip.dart';
import 'dart:convert';
import '../../services/corte_service.dart';
import '../../services/admin_service.dart';

class AdminFinancesScreen extends StatefulWidget {
  const AdminFinancesScreen({super.key});

  @override
  State<AdminFinancesScreen> createState() => _AdminFinancesScreenState();
}

class _AdminFinancesScreenState extends State<AdminFinancesScreen> {
  int _selectedPeriod = 0; // 0: Día, 1: Corte (2 Días), 2: Quincena, 3: Mes, 4: Personalizado
  DateTimeRange? _customDateRange;
  
  bool _isLoading = true;
  bool _isGeneratingCorte = false;
  
  double _ingresosBrutos = 0.0;
  double _comisionApp = 0.0;
  double _gananciaConductores = 0.0;
  double _retenciones = 0.0;
  
  // Desglose de Comisión
  double _comisionBancaria = 0.0;
  double _comisionTaxiSeguro = 0.0;
  double _referidoNivel1 = 0.0;
  double _referidoNivel2 = 0.0;
  double _accionistasSapi = 0.0;

  int _totalViajes = 0;
  double _ticketPromedio = 0.0;
  
  final List<FlSpot> _chartSpots = [];
  double _maxY = 1000.0;
  double _maxX = 6.0;
  
  final SupabaseClient _supabase = Supabase.instance.client;
  final CorteService _corteService = CorteService();
  final AdminService _adminService = AdminService();
  List<Trip> _trips = [];
  final List<Map<String, dynamic>> _driverStatsList = [];
  List<CortePeriodoGroup> _cortesGrupos = [];

  @override
  void initState() {
    super.initState();
    _fetchFinances();
  }
  
  DateTime _getStartDateForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // Día
        return DateTime(now.year, now.month, now.day);
      case 1: // Corte (2 Días)
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      case 2: // Quincena
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 14));
      case 3: // Mes
        return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      case 4: // Personalizado
        return _customDateRange?.start ?? DateTime(now.year, now.month, now.day);
      default:
        return DateTime(now.year, now.month, now.day);
    }
  }

  DateTime _getEndDateForPeriod() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 4: // Personalizado
        return _customDateRange?.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)) ?? 
               DateTime(now.year, now.month, now.day, 23, 59, 59);
      default:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
    }
  }

  Future<void> _fetchFinances() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final startDate = _getStartDateForPeriod();
      final endDate = _getEndDateForPeriod();

      // Sincronizar viajes finalizados a la tabla de facturación
      await _adminService.syncTripsToFacturacion();

      // Consultar tabla facturacion
      List<dynamic> factRows = [];
      try {
        final factRes = await _supabase.from('facturacion').select();
        factRows = (factRes as List<dynamic>?) ?? [];
      } catch (_) {}

      // Consultar tabla trips
      List<dynamic> allTrips = [];
      try {
        final tripsRes = await _supabase.from('trips').select();
        allTrips = (tripsRes as List<dynamic>?) ?? [];
      } catch (_) {}

      final driversResponse = await _supabase.from('conductores').select();
      final List<dynamic> driversData = (driversResponse as List<dynamic>?) ?? [];

      final Set<String> processedTripIds = {};
      final List<Trip> filteredTrips = [];

      for (var f in factRows) {
        String? tripId;
        String? driverId;
        final datos = f['datos_adicionales'];
        if (datos != null) {
          try {
            final map = datos is Map ? datos : jsonDecode(datos.toString());
            tripId = map['trip_id']?.toString();
            driverId = map['driver_id']?.toString();
          } catch (_) {}
        }
        
        if (tripId != null && tripId.isNotEmpty) {
          processedTripIds.add(tripId);
        }

        final rawCantidad = f['cantidad'];
        final double fare = (rawCantidad is num)
            ? rawCantidad.toDouble()
            : double.tryParse(rawCantidad?.toString() ?? '0') ?? 0.0;

        final dateStr = f['fecha_servicio'] ?? f['created_at'];
        DateTime? tripDate;
        if (dateStr != null) {
          tripDate = DateTime.tryParse(dateStr.toString())?.toLocal();
        }

        if (tripDate != null) {
          if (tripDate.isBefore(startDate) || tripDate.isAfter(endDate)) {
            continue;
          }
        }

        // Crear un Trip simulado para la vista
        filteredTrips.add(Trip(
          id: tripId ?? f['id']?.toString(),
          userId: '',
          driverId: driverId,
          originAddress: '',
          destinationAddress: '',
          status: f['status'] ?? 'completado',
          fare: fare,
          completedAt: tripDate,
          totalFinal: fare * 0.80,
        ));
      }

      for (var t in allTrips) {
        final tripId = (t['id'] ?? '').toString();
        if (processedTripIds.contains(tripId)) continue;

        final status = (t['status'] ?? '').toString().toLowerCase().trim();
        final isCompleted = status == 'completed' || status == 'completado' || status == 'finalizado';
        final fare = (t['fare'] as num?)?.toDouble() ?? 0.0;

        if ((isCompleted || fare > 0) && status != 'cancelled') {
          final dateStr = t['completed_at'] ?? t['created_at'];
          DateTime? tripDate;
          if (dateStr != null) {
            tripDate = DateTime.tryParse(dateStr.toString())?.toLocal();
          }

          if (tripDate != null) {
            if (tripDate.isBefore(startDate) || tripDate.isAfter(endDate)) {
              continue;
            }
          }

          // Use the real trip, but ensure totalFinal matches platform 20% rate if missing
          final tripObj = Trip.fromJson(t);
          filteredTrips.add(tripObj);
        }
      }

      _trips = filteredTrips;
      _calculateFinances(startDate, endDate, driversData);

      // Cargar cortes registrados
      try {
        _cortesGrupos = await _corteService.obtenerCortesAgrupados();
      } catch (corteErr) {
        debugPrint('Error cargando cortes agrupados: $corteErr');
      }
    } catch (e) {
      debugPrint('Error al cargar finanzas: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateFinances(DateTime startDate, DateTime endDate, List<dynamic> driversData) {
    double totalFare = 0.0;
    Map<String, double> driverFares = {}; // Bruto por conductor
    Map<String, double> driverEarned = {}; // Ganancia neta (total_final)
    Map<String, int> driverTrips = {};

    for (var trip in _trips) {
      double fare = trip.fare ?? 0.0;
      double earned = trip.totalFinal ?? (fare * 0.80); // 80% para el conductor
      
      totalFare += fare;
      
      if (trip.driverId != null) {
        driverFares[trip.driverId!] = (driverFares[trip.driverId!] ?? 0.0) + fare;
        driverEarned[trip.driverId!] = (driverEarned[trip.driverId!] ?? 0.0) + earned;
        driverTrips[trip.driverId!] = (driverTrips[trip.driverId!] ?? 0) + 1;
      }
    }

    _ingresosBrutos = totalFare;
    _comisionApp = totalFare * 0.20; // Cambiado a 20% para coincidir con Dashboard
    _gananciaConductores = driverEarned.values.fold(0.0, (sum, val) => sum + val);
    
    // Desglose del 20%
    _comisionBancaria = _comisionApp * 0.20;
    _comisionTaxiSeguro = _comisionApp * 0.30;
    _referidoNivel1 = _comisionApp * 0.075;
    _referidoNivel2 = _comisionApp * 0.025;
    _accionistasSapi = _comisionApp * 0.40;
    
    _retenciones = totalFare * 0.08; // Estimado 8%
    _totalViajes = _trips.length;
    _ticketPromedio = _totalViajes > 0 ? totalFare / _totalViajes : 0.0;

    _driverStatsList.clear();
    driverFares.forEach((driverId, fare) {
      final driverInfo = driversData.firstWhere(
        (d) => d['user_id'] == driverId, 
        orElse: () => <String, dynamic>{}
      );
      String name = driverInfo['Nombre'] ?? 'Conductor Desconocido';
      if (driverInfo['Apellidos'] != null) {
        name += ' ${driverInfo['Apellidos']}';
      }

      double earned = driverEarned[driverId] ?? (fare * 0.80);

      _driverStatsList.add({
        'name': name,
        'totalFare': fare,
        'trips': driverTrips[driverId] ?? 0,
        'driverEarned': earned,
        'appCommission': fare - earned, // Lo que resta es para la plataforma
      });
    });
    
    // Sort by total fare descending
    _driverStatsList.sort((a, b) => (b['totalFare'] as double).compareTo(a['totalFare'] as double));

    _buildChartData(startDate, endDate);
  }

  String _formatDateString(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _buildChartData(DateTime startDate, DateTime endDate) {
    _chartSpots.clear();
    double maxY = 0;
    
    final diff = endDate.difference(startDate);
    final days = diff.inDays;
    
    if (_selectedPeriod == 0 || days == 0) {
      // Bloques de 3 horas
      _maxX = 7.0; 
      List<double> hourlyFares = List.filled(8, 0.0);
      for (var trip in _trips) {
        if (trip.completedAt != null) {
          // Ajustamos hora local
          final localTime = trip.completedAt!.toLocal();
          int block = localTime.hour ~/ 3;
          if (block >= 0 && block < 8) {
            hourlyFares[block] += (trip.fare ?? 0.0);
          }
        }
      }
      for (int i = 0; i < 8; i++) {
        _chartSpots.add(FlSpot(i.toDouble(), hourlyFares[i]));
        if (hourlyFares[i] > maxY) maxY = hourlyFares[i];
      }
    } else {
      // Por días
      _maxX = days.toDouble();
      Map<String, double> dailyFares = {};
      
      for (int i = 0; i <= days; i++) {
        final d = startDate.add(Duration(days: i));
        dailyFares[_formatDateString(d)] = 0.0;
      }
      
      for (var trip in _trips) {
        if (trip.completedAt != null) {
          final key = _formatDateString(trip.completedAt!.toLocal());
          if (dailyFares.containsKey(key)) {
            dailyFares[key] = dailyFares[key]! + (trip.fare ?? 0.0);
          }
        }
      }
      
      int i = 0;
      dailyFares.forEach((key, val) {
        _chartSpots.add(FlSpot(i.toDouble(), val));
        if (val > maxY) maxY = val;
        i++;
      });
    }
    
    _maxY = maxY > 0 ? maxY * 1.2 : 100.0; 
  }

  String _formatCurrency(double amount) {
    String fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAll(reg, ',');
    return '\$${parts[0]}.${parts[1]}';
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.black, // body text color
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedPeriod = 4;
        _customDateRange = picked;
      });
      _fetchFinances();
    } else if (_selectedPeriod == 4 && _customDateRange == null) {
      setState(() {
        _selectedPeriod = 0;
      });
    }
  }

  void _onPeriodChanged(int index) {
    if (index == 4) {
      _selectCustomDateRange();
    } else {
      setState(() {
        _selectedPeriod = index;
      });
      _fetchFinances();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Finanzas Globales',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Selector de Periodo
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPeriodTab('Día', 0),
                  _buildPeriodTab('Corte (2 Días)', 1),
                  _buildPeriodTab('Quincena', 2),
                  _buildPeriodTab('Mes', 3),
                  _buildPeriodTab('Custom', 4),
                ],
              ),
            ),
          ),
          
          if (_selectedPeriod == 4 && _customDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Center(
                child: Text(
                  '${_customDateRange!.start.day}/${_customDateRange!.start.month}/${_customDateRange!.start.year} - ${_customDateRange!.end.day}/${_customDateRange!.end.month}/${_customDateRange!.end.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                ),
              ),
            ),
          
          const SizedBox(height: 20),

          // Tarjetas de Métricas Rápidas
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Ingresos Brutos',
                  '${_formatCurrency(_ingresosBrutos)} MXN',
                  'Total',
                  Colors.black,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Comisión App (20%)',
                  '${_formatCurrency(_comisionApp)} MXN',
                  'Bruto',
                  const Color(0xFF050505),
                  Icons.account_balance,
                  isDark: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gráfica de Línea de Ingresos (fl_chart)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Text(
                    'Evolución de Ingresos (MXN)',
                    style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    _selectedPeriod == 0 ? 'Ingresos cada 3 horas' : 'Ingresos diarios generados por la flota',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 220,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            getTitlesWidget: (value, meta) {
                              if (value == _maxY) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: Text(
                                  '\$${(value / 1000).toStringAsFixed(1)}k',
                                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final int val = value.toInt();
                              final diff = _getEndDateForPeriod().difference(_getStartDateForPeriod());
                              final days = diff.inDays;
                              
                              if (_selectedPeriod == 0 || days == 0) {
                                 final labels = ['12a', '3a', '6a', '9a', '12p', '3p', '6p', '9p'];
                                 if (val >= 0 && val < labels.length) {
                                   return Padding(
                                     padding: const EdgeInsets.only(top: 6.0),
                                     child: Text(labels[val], style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                                   );
                                 }
                              } else {
                                 int step = 1;
                                 if (days > 45) {
                                   step = 10;
                                 } else if (days > 20) {
                                   step = 5;
                                 } else if (days > 10) {
                                   step = 3;
                                 } else if (days > 7) {
                                   step = 2;
                                 }
                                 
                                 if (val % step == 0 && val <= days) {
                                    final d = _getStartDateForPeriod().add(Duration(days: val));
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Text('${d.day}/${d.month}', style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold)),
                                    );
                                 }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: _maxX,
                      minY: 0,
                      maxY: _maxY,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _chartSpots.isEmpty ? const [FlSpot(0, 0)] : _chartSpots,
                          isCurved: true,
                          color: const Color(0xFF050505),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF050505).withValues(alpha: 0.25),
                          ),
                          dotData: FlDotData(show: _maxX <= 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 20),

          // Desglose de Distribución Financiera
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desglose de Reparto de Ganancias',
                  style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                _buildFinanceRow('Ganancia Conductores (80%)', _formatCurrency(_gananciaConductores), Colors.black87),
                _buildFinanceRow('Comisión Plataforma (20%)', _formatCurrency(_comisionApp), Colors.black87, isBold: true),
                const Divider(height: 16),
                const Text('Detalle de Comisión Plataforma', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildFinanceRow('• Bancaria (20% de comisión)', _formatCurrency(_comisionBancaria), Colors.red),
                _buildFinanceRow('• Taxi Seguro (30% de comisión)', _formatCurrency(_comisionTaxiSeguro), Colors.green),
                _buildFinanceRow('• Referido Nivel 1 (7.5% de comisión)', _formatCurrency(_referidoNivel1), Colors.amber),
                _buildFinanceRow('• Referido Nivel 2 (2.5% de comisión)', _formatCurrency(_referidoNivel2), Colors.orange),
                _buildFinanceRow('• Accionistas SAPI (40% de comisión)', _formatCurrency(_accionistasSapi), Colors.purple),
                const Divider(height: 24),
                _buildFinanceRow('Retenciones fiscales (estimado 8%)', _formatCurrency(_retenciones), Colors.grey),
                const Divider(height: 24),
                _buildFinanceRow('Ticket Promedio por Viaje', _formatCurrency(_ticketPromedio), Colors.black, isBold: true),
                _buildFinanceRow('Total Viajes en el Periodo', '$_totalViajes viajes', Colors.black, isBold: true),
              ],
            ),
          ).animate().fade(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 20),

          // Sección de Cortes de Conductores (Cada 2 Días)
          _buildCortesSection(),

          const SizedBox(height: 20),

          // Tabla de Conductores y sus Montos
          if (_driverStatsList.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desempeño por Conductor',
                    style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ..._driverStatsList.map((stat) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  stat['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${stat['trips']} viajes',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Generado', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text(_formatCurrency(stat['totalFare']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Ganancia (80%)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  Text(_formatCurrency(stat['driverEarned']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String title, int index) {
    final bool isSelected = _selectedPeriod == index;
    return GestureDetector(
      onTap: () => _onPeriodChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Google Sans',
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.black54,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, String growth, Color accentColor, IconData icon, {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: accentColor, size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white24 : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  growth,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF050505) : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================
  // SECCIÓN DE CORTES CADA 2 DÍAS & COBRO
  // ==========================================

  Widget _buildCortesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF050505).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.event_repeat_rounded, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Flexible(
                          child: Text(
                            'Cortes de Conductores',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fechas de corte cada 2 días para cobro de comisiones',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isGeneratingCorte ? null : _generarCorteActual,
                icon: _isGeneratingCorte
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.flash_on_rounded, size: 16),
                label: Text(
                  _isGeneratingCorte ? 'Generando...' : 'Generar Corte',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF050505),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_cortesGrupos.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text(
                    'No hay registros de cortes aún',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Presiona "Generar Corte" para calcular las comisiones de los últimos 2 días basadas en los viajes completados.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ..._cortesGrupos.map((grupo) => _buildGrupoCorteCard(grupo)),
        ],
      ),
    ).animate().fade(duration: 400.ms, delay: 180.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildGrupoCorteCard(CortePeriodoGroup grupo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 18, color: Colors.black87),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Corte: ${grupo.periodoInicio} al ${grupo.periodoFin}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Text(
                  '${grupo.cortes.length} cond. • ${grupo.totalViajes} viajes',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  'Por Cobrar: ${_formatCurrency(grupo.totalCobrar)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: grupo.cortes.map((corte) => _buildCorteConductorRow(corte)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorteConductorRow(CorteConductor corte) {
    final bool esPagado = corte.estatusPago.toLowerCase() == 'pagado';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: esPagado ? Colors.green.shade200 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Conductor + Estado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      corte.nombreConductor,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (corte.correoConductor != null && corte.correoConductor!.isNotEmpty)
                      Text(
                        corte.correoConductor!,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: esPagado ? Colors.green.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: esPagado ? Colors.green.shade200 : Colors.amber.shade200),
                ),
                child: Text(
                  esPagado ? 'PAGADO' : 'PENDIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: esPagado ? Colors.green.shade800 : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Desglose de Viajes y Efectivo vs Tarjeta
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric('Viajes', '${corte.totalViajes}'),
              _buildMiniMetric('Generado', _formatCurrency(corte.totalGenerado)),
              _buildMiniMetric('Efectivo', _formatCurrency(corte.totalEfectivo)),
              _buildMiniMetric('Tarjeta', _formatCurrency(corte.totalTarjeta)),
            ],
          ),
          const SizedBox(height: 10),
          // Saldo a pagar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saldo a Pagar (Comisión 20%):',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${_formatCurrency(corte.saldoAPagar)} MXN',
                  style: const TextStyle(
                    color: Color(0xFF050505),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Correo enviado indicator + Acciones
          Row(
            children: [
              if (corte.correoEnviado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.mark_email_read_rounded, size: 13, color: Color(0xFF050505)),
                      SizedBox(width: 4),
                      Text(
                        'Correo enviado',
                        style: TextStyle(color: Color(0xFF050505), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Sin notificar',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              const Spacer(),
              // Botón Enviar Correo
              OutlinedButton.icon(
                onPressed: () => _enviarCorreoCorte(corte),
                icon: const Icon(Icons.email_outlined, size: 14),
                label: Text(corte.correoEnviado ? 'Reenviar' : 'Enviar Correo', style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 6),
              // Botón Marcar Pagado
              if (!esPagado)
                ElevatedButton.icon(
                  onPressed: () => _marcarCortePagado(corte),
                  icon: const Icon(Icons.check_circle_outline, size: 14),
                  label: const Text('Pagado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFF050505),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _generarCorteActual() async {
    setState(() => _isGeneratingCorte = true);
    try {
      final success = await _corteService.generarCorte2Dias();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
              ? '✅ Corte de 2 días generado exitosamente.' 
              : '⚠️ No se encontraron viajes nuevos o hubo un problema al generar el corte.'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _fetchFinances();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar corte: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingCorte = false);
      }
    }
  }

  Future<void> _enviarCorreoCorte(CorteConductor corte) async {
    final launched = await _corteService.enviarCorreoCobro(corte);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(launched
            ? '📧 Abriendo correo para ${corte.nombreConductor}...'
            : '⚠️ No se pudo abrir la app de correo.'),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchFinances();
    }
  }

  Future<void> _marcarCortePagado(CorteConductor corte) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('¿Deseas marcar como liquidado el saldo de ${_formatCurrency(corte.saldoAPagar)} MXN de ${corte.nombreConductor}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF050505),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await _corteService.marcarCortePagado(corte.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok 
              ? '✅ Corte marcado como pagado exitosamente.' 
              : 'Error al marcar como pagado.'),
            backgroundColor: Colors.black,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchFinances();
      }
    }
  }
}
