import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/admin_service.dart';
import '../../screens/admin/admin_finances_screen.dart';

class DashboardRevenueCard extends StatefulWidget {
  final AdminService adminService;
  final VoidCallback? onRefreshRequested;
  final String? driverId;

  const DashboardRevenueCard({
    super.key,
    required this.adminService,
    this.onRefreshRequested,
    this.driverId,
  });

  @override
  State<DashboardRevenueCard> createState() => DashboardRevenueCardState();
}

class DashboardRevenueCardState extends State<DashboardRevenueCard> {
  int _selectedFilterIndex = 0; // 0: Hoy, 1: 7 Días, 2: 30 Días, 3: Custom
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = true;
  DashboardFinancialData? _finances;

  @override
  void initState() {
    super.initState();
    _applyPreset(0, shouldFetch: false);
    _loadFinances();
  }

  void _applyPreset(int index, {bool shouldFetch = true}) {
    final now = DateTime.now();
    setState(() {
      _selectedFilterIndex = index;
      if (index == 0) {
        // Hoy
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (index == 1) {
        // Últimos 7 días
        _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (index == 2) {
        // Últimos 30 días
        _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      }
    });

    if (shouldFetch) {
      _loadFinances();
    }
  }

  Future<void> reload() async {
    await _loadFinances();
  }

  Future<void> _loadFinances() async {
    setState(() => _isLoading = true);
    final data = await widget.adminService.getDashboardFinances(
      startDate: _startDate,
      endDate: _endDate,
      driverId: widget.driverId,
    );
    if (mounted) {
      setState(() {
        _finances = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Color(0xFF050505),
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilterIndex = 3;
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
      _loadFinances();
    }
  }

  String _formatCurrency(double amount) {
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAll(reg, ',');
    return '\$${parts[0]}.${parts[1]}';
  }

  String _getRangeLabel() {
    if (_selectedFilterIndex == 0) {
      return 'Hoy (${_startDate.day}/${_startDate.month})';
    } else if (_selectedFilterIndex == 1) {
      return 'Últimos 7 días';
    } else if (_selectedFilterIndex == 2) {
      return 'Últimos 30 días';
    } else {
      return '${_startDate.day}/${_startDate.month}/${_startDate.year} - ${_endDate.day}/${_endDate.month}/${_endDate.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _finances ?? DashboardFinancialData.empty();
    final totalRev = data.totalRevenue;
    final commission = data.platformCommission;
    final cashTotal = data.cashTotal;
    final cardTotal = data.cardTotal;

    final double cashPct = totalRev > 0 ? (cashTotal / totalRev) * 100 : 0.0;
    final double cardPct = totalRev > 0 ? (cardTotal / totalRev) * 100 : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Título y Botón Selector de Fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF050505).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.insights, size: 16, color: Colors.black),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedFilterIndex == 0 ? 'Ingresos de Hoy' : 'Ingresos del Periodo',
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getRangeLabel(),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              // Botón de Selector de Fecha
              InkWell(
                onTap: _pickCustomDateRange,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.calendar_month_outlined, size: 16, color: Colors.black),
                      SizedBox(width: 6),
                      Text(
                        'Filtrar',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Chips rápidos de periodo: Hoy, 7 Días, 30 Días, Personalizado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Hoy', 0),
                const SizedBox(width: 8),
                _buildFilterChip('7 Días', 1),
                const SizedBox(width: 8),
                _buildFilterChip('30 Días', 2),
                const SizedBox(width: 8),
                _buildFilterChip('Personalizado', 3, isCustomAction: true),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tarjetas de Monto Total y Comisión
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF050505), // Pure TaxiSeguro Black
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL GENERADO',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatCurrency(totalRev)} MXN',
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${data.totalTrips} ${data.totalTrips == 1 ? "viaje completado" : "viajes completados"}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF050505).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.monetization_on, color: Color(0xFF050505), size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Comisión (20%)',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              color: Color(0xFF050505),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(commission),
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          color: Color(0xFF050505),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Gráfica fl_chart
          if (_isLoading)
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator(color: Colors.black)),
            )
          else
            SizedBox(
              height: 185,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          if (value == data.maxY) return const SizedBox.shrink();
                          if (value < 0) return const SizedBox.shrink();
                          if (value >= 1000) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Text(
                                '\$${(value / 1000).toStringAsFixed(1)}k',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Text(
                              '\$${value.toInt()}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final int idx = value.toInt();
                          if (data.isSingleDay) {
                            if (idx >= 0 && idx < data.xLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  data.xLabels[idx],
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }
                          } else {
                            final int totalSpots = data.chartSpots.length;
                            int step = 1;
                            if (totalSpots > 15) {
                              step = 4;
                            } else if (totalSpots > 8) {
                              step = 2;
                            }

                            if (idx % step == 0 && idx < data.xLabels.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  data.xLabels[idx],
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                  maxX: data.maxX,
                  minY: 0,
                  maxY: data.maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.chartSpots.isEmpty ? const [FlSpot(0, 0)] : data.chartSpots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFF050505),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: data.maxX <= 15,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF050505),
                          strokeWidth: 2,
                          strokeColor: Colors.black,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF050505).withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.black,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '\$${spot.y.toStringAsFixed(2)} MXN',
                            const TextStyle(
                              color: Color(0xFF050505),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 18),

          // SEGMENTACIÓN POR MÉTODO DE PAGO (metodo_pago / payment_method)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.pie_chart_outline, size: 16, color: Colors.black54),
                  SizedBox(width: 6),
                  Text(
                    'Segmentado por Método de Pago',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (totalRev > 0)
                Text(
                  '${data.totalTrips} viajes',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Barra visual de proporción segmentada
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: cashPct > 0 ? (cashPct * 10).toInt() : (cardPct > 0 ? 0 : 1),
                    child: Container(
                      color: const Color(0xFF050505),
                    ),
                  ),
                  Expanded(
                    flex: cardPct > 0 ? (cardPct * 10).toInt() : 0,
                    child: Container(
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Tarjetas de Métodos de Pago: Efectivo vs Tarjeta
          Row(
            children: [
              // 1. Efectivo
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF050505).withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.payments_outlined, size: 16, color: Colors.black),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${cashPct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Color(0xFF050505),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pago en Efectivo',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatCurrency(cashTotal),
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.cashTrips} viajes',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // 2. Tarjeta
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF050505).withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.credit_card_rounded, size: 16, color: Colors.black),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${cardPct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Color(0xFF050505),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pago con Tarjeta',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatCurrency(cardTotal),
                          style: const TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${data.cardTrips} viajes',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // BOTÓN QUE LLEVA A FINANZAS GENERALES
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminFinancesScreen()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Ver Finanzas Generales',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Color(0xFF050505), size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index, {bool isCustomAction = false}) {
    final bool isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () {
        if (isCustomAction) {
          _pickCustomDateRange();
        } else {
          _applyPreset(index);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Google Sans',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF050505) : Colors.black87,
          ),
        ),
      ),
    );
  }
}
