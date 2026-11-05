import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';

class DriverFinancesScreen extends StatefulWidget {
  const DriverFinancesScreen({super.key});

  @override
  State<DriverFinancesScreen> createState() => _DriverFinancesScreenState();
}

class _DriverFinancesScreenState extends State<DriverFinancesScreen> {
  final TripService _tripService = TripService();
  bool _isLoading = true;
  List<Trip> _allTrips = [];
  List<Trip> _filteredTrips = [];
  String? _driverId;

  DateTime? _startDate;
  DateTime? _endDate;

  final Map<String, List<Trip>> _groupedTrips = {};
  final Map<String, double> _monthlyEarnings = {};
  double _totalEarnings = 0.0;
  DateTime? _nextCutoffDate;

  // Ganancias por referidos (20% del 1er viaje)
  double _totalReferralEarnings = 0.0;
  int _totalReferralsCount = 0;
  int _activeReferralsCount = 0;
  List<Map<String, dynamic>> _driverReferrals = [];

  @override
  void initState() {
    super.initState();
    _driverId = Supabase.instance.client.auth.currentUser?.id;
    
    // Set default range to 'All time' so they see their trips immediately
    _startDate = null;
    _endDate = null; 
    
    _loadAllFinances();
  }

  Future<void> _loadAllFinances() async {
    if (_driverId == null) return;
    setState(() => _isLoading = true);

    try {
      final trips = await _tripService.getAllDriverCompletedTrips(_driverId!);
      _allTrips = trips;
      _applyDateFilter();

      try {
        final cutoffRes = await Supabase.instance.client
            .from('fechas_corte')
            .select('fecha_corte')
            .order('fecha_corte', ascending: false)
            .limit(1);
        if (cutoffRes.isNotEmpty) {
          _nextCutoffDate = DateTime.tryParse(cutoffRes[0]['fecha_corte'].toString());
        }
      } catch (_) {}

      // Cargar referidos del conductor y comisiones acumuladas (20%)
      try {
        final condRes = await Supabase.instance.client
            .from('conductores')
            .select('nombre, nombre_completo, telefono')
            .eq('user_id', _driverId!)
            .maybeSingle();

        final String driverPhone = (condRes?['telefono'] ?? '').toString();
        final String driverName = (condRes?['nombre_completo'] ?? condRes?['nombre'] ?? '').toString();
        final cleanDriverPhone = driverPhone.replaceAll(RegExp(r'\D'), '');
        final cleanName = driverName.trim().toLowerCase();

        if (cleanDriverPhone.isNotEmpty || cleanName.isNotEmpty) {
          final refUsers = await Supabase.instance.client
              .from('users')
              .select('id, nombre, usuario_activado, comision_referido, time_referido, created_at, referido')
              .not('referido', 'is', null);

          final list = List<Map<String, dynamic>>.from(refUsers);
          final matched = list.where((u) {
            final ref = (u['referido'] ?? '').toString().trim().toLowerCase();
            if (ref.isEmpty) return false;
            final cleanRefDigits = ref.replaceAll(RegExp(r'\D'), '');

            // 1. Coincidencia por teléfono del conductor
            if (cleanDriverPhone.isNotEmpty && cleanRefDigits.isNotEmpty) {
              if (cleanRefDigits == cleanDriverPhone ||
                  cleanRefDigits.endsWith(cleanDriverPhone) ||
                  cleanDriverPhone.endsWith(cleanRefDigits)) {
                return true;
              }
            }

            // 2. Coincidencia por nombre para registros existentes
            if (cleanName.isNotEmpty && (ref == cleanName || ref.contains(cleanName) || cleanName.contains(ref))) {
              return true;
            }

            return false;
          }).toList();

          double refEarnings = 0.0;
          int activeCount = 0;
          for (var u in matched) {
            if (u['usuario_activado'] == true) {
              activeCount++;
              final com = (u['comision_referido'] as num?)?.toDouble() ?? 0.0;
              refEarnings += com;
            }
          }

          _totalReferralEarnings = refEarnings;
          _totalReferralsCount = matched.length;
          _activeReferralsCount = activeCount;
          _driverReferrals = matched;
        }
      } catch (refErr) {
        print('Error cargando referidos del conductor: $refErr');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyDateFilter() {
    if (_startDate == null || _endDate == null) {
      _filteredTrips = List.from(_allTrips);
    } else {
      _filteredTrips = _allTrips.where((trip) {
        final date = trip.completedAt ?? trip.createdAt ?? DateTime.now();
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        return date.isAfter(start) && date.isBefore(end);
      }).toList();
    }
    _groupTripsByMonth(_filteredTrips);
  }

  void _groupTripsByMonth(List<Trip> trips) {
    _groupedTrips.clear();
    _monthlyEarnings.clear();
    _totalEarnings = 0.0;

    for (var trip in trips) {
      final date = trip.completedAt ?? trip.createdAt ?? DateTime.now();
      
      final monthNames = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];
      final monthStr = '${monthNames[date.month - 1]} ${date.year}';

      if (!_groupedTrips.containsKey(monthStr)) {
        _groupedTrips[monthStr] = [];
        _monthlyEarnings[monthStr] = 0.0;
      }

      _groupedTrips[monthStr]!.add(trip);
      final fare = (trip.fare ?? 0.0);
      _monthlyEarnings[monthStr] = (_monthlyEarnings[monthStr] ?? 0) + fare;
      _totalEarnings += fare;
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
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
        _startDate = picked.start;
        _endDate = picked.end;
        _applyDateFilter();
      });
    }
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _applyDateFilter();
    });
  }

  bool _isRangeGreaterThan20Days() {
    if (_startDate == null || _endDate == null) return true; // All time
    return _endDate!.difference(_startDate!).inDays > 20;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Tus Finanzas',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              onRefresh: _loadAllFinances,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDateFilter(),
                          const SizedBox(height: 16),
                          if (_isRangeGreaterThan20Days())
                            _buildTotalAllTimeCard()
                          else
                            _buildChartSection(),
                          const SizedBox(height: 16),
                          _buildReferralsEarningsCard(),
                          const SizedBox(height: 24),
                          const Text(
                            'Historial de Registros',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_filteredTrips.isEmpty)
                            _buildEmptyState()
                          else ...[
                            ..._groupedTrips.keys.map((month) => _buildMonthSection(month)),
                            if (!_isRangeGreaterThan20Days()) ...[
                              const SizedBox(height: 24),
                              _buildTotalAllTimeCard(),
                            ],
                          ],
                          const SizedBox(height: 120), // Padding extra para que el menú no tape el final
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDateFilter() {
    String dateRangeText = 'Todo el tiempo';
    if (_startDate != null && _endDate != null) {
      final s = '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}';
      final e = '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}';
      dateRangeText = '$s - $e';
    }

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.black54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateRangeText,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Google Sans', fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.black54),
                ],
              ),
            ),
          ),
        ),
        if (_startDate != null || _endDate != null) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _clearDates,
              icon: const Icon(Icons.clear, color: Colors.redAccent),
              tooltip: 'Borrar filtro',
            ),
          )
        ]
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'Aún no hay registros de finanzas en estas fechas.',
            style: TextStyle(fontSize: 14, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    bool isDaily = true;
    if (_startDate != null && _endDate != null) {
      if (_endDate!.difference(_startDate!).inDays > 35) {
        isDaily = false;
      }
    } else {
      isDaily = false; 
    }

    Map<String, double> chartData = {};
    
    // Pre-populate with 0s for the selected date range to ensure chart always renders
    if (_startDate != null && _endDate != null) {
      if (isDaily) {
        DateTime current = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
        while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
          chartData['${current.day}/${current.month}'] = 0.0;
          current = current.add(const Duration(days: 1));
        }
      } else {
        DateTime current = DateTime(_startDate!.year, _startDate!.month, 1);
        final endMonth = DateTime(_endDate!.year, _endDate!.month, 1);
        while (current.isBefore(endMonth) || current.isAtSameMomentAs(endMonth)) {
          chartData['${current.month}/${current.year}'] = 0.0;
          current = DateTime(current.year, current.month + 1, 1);
        }
      }
    }

    for (var trip in _filteredTrips) {
      final d = trip.completedAt ?? trip.createdAt ?? DateTime.now();
      String key;
      if (isDaily) {
        key = '${d.day}/${d.month}';
      } else {
        key = '${d.month}/${d.year}';
      }
      chartData[key] = (chartData[key] ?? 0.0) + ((trip.fare ?? 0.0) * 0.8); // Gráfica muestra ganancias reales
    }

    final sortedKeys = chartData.keys.toList()..sort((a, b) {
      if (isDaily) {
        final pA = a.split('/');
        final pB = b.split('/');
        final dateA = DateTime(2000, int.parse(pA[1]), int.parse(pA[0]));
        final dateB = DateTime(2000, int.parse(pB[1]), int.parse(pB[0]));
        return dateA.compareTo(dateB);
      } else {
        final pA = a.split('/');
        final pB = b.split('/');
        final dateA = DateTime(int.parse(pA[1]), int.parse(pA[0]));
        final dateB = DateTime(int.parse(pB[1]), int.parse(pB[0]));
        return dateA.compareTo(dateB);
      }
    });

    List<BarChartGroupData> barGroups = [];
    double maxY = 0;
    for (int i = 0; i < sortedKeys.length; i++) {
      final val = chartData[sortedKeys[i]]!;
      if (val > maxY) maxY = val;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFF050505), // Modern Black
              width: 16,
              borderRadius: BorderRadius.circular(8),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY * 1.2,
                color: Colors.grey[100],
              ),
            ),
          ],
        ),
      );
    }

    double xInterval = (sortedKeys.length / 6).ceilToDouble();
    if (xInterval < 1) xInterval = 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 8),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isDaily ? Icons.show_chart : Icons.bar_chart, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                isDaily ? 'Ganancias por día' : 'Ganancias por mes',
                style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: barGroups.isEmpty 
              ? const Center(child: Text('Sin datos para graficar'))
              : BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.2,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedKeys.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              sortedKeys[value.toInt()],
                              style: const TextStyle(fontSize: 10, color: Colors.black54),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey[200],
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAllTimeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF2E2E2E), // AppColors.charcoal
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Total Cobrado',
            style: TextStyle(
              fontFamily: 'Google Sans',
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${_totalEarnings.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Google Sans',
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tus Ganancias de Viajes (80%)',
            style: TextStyle(
              fontFamily: 'Google Sans',
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${(_totalEarnings * 0.8).toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Google Sans',
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_totalReferralEarnings > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people_alt, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '+ \$${_totalReferralEarnings.toStringAsFixed(2)} por referidos (20%)',
                    style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF050505),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Total Acumulado a Recibir',
            style: TextStyle(
              fontFamily: 'Google Sans',
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${((_totalEarnings * 0.8) + _totalReferralEarnings).toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Google Sans',
              color: Colors.white, // AppColors.pureWhite
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_filteredTrips.length} viajes en este periodo',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          if (_nextCutoffDate != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available, color: Colors.white54, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Próximo Corte:',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_nextCutoffDate!.day.toString().padLeft(2, '0')}/${_nextCutoffDate!.month.toString().padLeft(2, '0')}/${_nextCutoffDate!.year}',
                    style: const TextStyle(
                      fontFamily: 'Google Sans',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthSection(String month) {
    final trips = _groupedTrips[month]!;
    final earnings = _monthlyEarnings[month]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: month == _groupedTrips.keys.first,
          title: Text(
            month,
            style: const TextStyle(
              fontFamily: 'Google Sans',
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            '${trips.length} viaje(s)',
            style: const TextStyle(color: Colors.black54),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total: \$${earnings.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              Text(
                '\$${(earnings * 0.8).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: trips.map((trip) => _buildTripItem(trip)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripItem(Trip trip) {
    final date = trip.completedAt ?? trip.createdAt ?? DateTime.now();
    final timeString = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final fare = (trip.fare ?? 0.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.done, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.destinationAddress.isNotEmpty
                      ? trip.destinationAddress
                      : 'Viaje finalizado',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeString,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Total: \$${fare.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${(fare * 0.8).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralsEarningsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group_add, color: Colors.black87, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Mis Referidos',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '20% Bono',
                  style: TextStyle(
                    fontFamily: 'Google Sans',
                    color: Color(0xFF050505),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ganado por Referidos',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_totalReferralEarnings.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        color: Color(0xFF2E7D32),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usuarios Activos',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_activeReferralsCount / $_totalReferralsCount',
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _totalReferralsCount == 0
                        ? 'Comparte tu número de teléfono (+52) con tus pasajeros para que lo ingresen al registrarse y ganes el 20% de su primer viaje.'
                        : 'Recibes el 20% del monto total del primer viaje que complete cada usuario que refieras.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_driverReferrals.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            ..._driverReferrals.take(4).map((u) {
              final name = (u['nombre'] ?? 'Usuario').toString();
              final isAct = u['usuario_activado'] == true;
              final com = (u['comision_referido'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isAct ? Icons.check_circle : Icons.hourglass_top,
                          size: 14,
                          color: isAct ? const Color(0xFF2E7D32) : Colors.amber.shade800,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      isAct ? '+\$${com.toStringAsFixed(2)}' : 'Pendiente',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isAct ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
