import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'admin_cutoff_detail_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCutoffDatesScreen extends StatefulWidget {
  const AdminCutoffDatesScreen({super.key});

  @override
  State<AdminCutoffDatesScreen> createState() => _AdminCutoffDatesScreenState();
}

class _AdminCutoffDatesScreenState extends State<AdminCutoffDatesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<CutoffDateModel> _cutoffs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_MX', null).then((_) {
      _loadCutoffs();
    });
  }

  Future<void> _loadCutoffs() async {
    try {
      final res = await _supabase
          .from('fechas_corte')
          .select('*, cortes_conductores(*)')
          .order('fecha_corte', ascending: false);

      final List<dynamic> rows = (res as List<dynamic>?) ?? [];

      if (rows.isNotEmpty) {
        final List<CutoffDateModel> loaded = [];
        for (var row in rows) {
          final dateStr = row['fecha_corte'] ?? row['created_at'];
          final date = DateTime.tryParse(dateStr.toString()) ?? DateTime.now();

          final List<dynamic> conductoresRaw = (row['cortes_conductores'] as List<dynamic>?) ?? [];
          final List<CutoffDriverItem> paid = [];
          final List<CutoffDriverItem> pending = [];

          for (var c in conductoresRaw) {
            final item = CutoffDriverItem(
              id: c['conductor_id']?.toString() ?? '',
              name: c['nombre_conductor']?.toString() ?? 'Conductor',
              totalRevenue: (c['total_generado'] as num?)?.toDouble() ?? 0.0,
              amountDue: (c['saldo_a_pagar'] as num?)?.toDouble() ??
                  ((c['comision_app'] as num?)?.toDouble() ?? 0.0),
              isPaid: (c['estatus_pago'] ?? '').toString().toLowerCase() == 'pagado',
            );

            if (item.isPaid) {
              paid.add(item);
            } else {
              pending.add(item);
            }
          }

          loaded.add(CutoffDateModel(
            id: row['id']?.toString(),
            date: date,
            startDate: DateTime.tryParse(row['periodo_inicio']?.toString() ?? ''),
            endDate: DateTime.tryParse(row['periodo_fin']?.toString() ?? ''),
            paidDrivers: paid,
            pendingDrivers: pending,
          ));
        }

        if (mounted) {
          setState(() {
            _cutoffs = loaded;
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error al consultar fechas_corte en Supabase: $e');
    }

    // Si fechas_corte aún no tiene filas creadas por pg_cron, cargamos los conductores REALES de la base de datos
    await _loadFromConductoresFallback();
  }

  Future<void> _loadFromConductoresFallback() async {
    try {
      final res = await _supabase
          .from('conductores')
          .select('id, user_id, nombre, nombre_completo, Aprobacion, estatus');
      final List<dynamic> rows = (res as List<dynamic>?) ?? [];

      if (rows.isNotEmpty) {
        final List<CutoffDriverItem> allDrivers = [];
        for (int i = 0; i < rows.length; i++) {
          final d = rows[i];
          final status = (d['estatus'] ?? '').toString().toLowerCase();
          final aprobacion = (d['Aprobación'] ?? d['Aprobacion'] ?? d['aprobacion'] ?? '').toString().toLowerCase();
          
          if (status == 'activo' || aprobacion == 'aprobado') {
            final String nombre = (d['nombre_completo'] ?? d['nombre'] ?? 'Conductor').toString();
            // Mostrar datos reales en vez de mock (si no hay corte creado, muestran 0 hasta que corra el cron)
            allDrivers.add(CutoffDriverItem(
              id: (d['user_id'] ?? d['id'])?.toString() ?? '',
              name: nombre,
              totalRevenue: 0.0,
              amountDue: 0.0,
              isPaid: false,
            ));
          }
        }

        final now = DateTime.now();
        // Solo un corte virtual como fallback mostrando que está próximo o pendiente
        final virtualCutoff = CutoffDateModel(
          date: now,
          paidDrivers: [],
          pendingDrivers: allDrivers,
        );

        if (mounted) {
          setState(() {
            _cutoffs = [virtualCutoff];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error cargando conductores reales fallback: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        title: const Text(
          'Fechas de Corte',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              itemCount: _cutoffs.length,
              itemBuilder: (context, index) {
                final cutoff = _cutoffs[index];
                return _buildCutoffItem(cutoff, index);
              },
            ),
    );
  }

  String _getCutoffTitle(CutoffDateModel cutoff) {
    final now = DateTime.now();
    final date = cutoff.date;
    final today = DateTime(now.year, now.month, now.day);
    final cutoffDay = DateTime(date.year, date.month, date.day);
    
    final difference = cutoffDay.difference(today).inDays;
    
    if (difference == 0) return 'Corte de Hoy';
    if (difference == 1) return 'Corte de Mañana';
    if (difference == -1) return 'Corte de Ayer';
    if (difference > 1) return 'Corte en $difference Días';
    return 'Corte de hace ${difference.abs()} Días';
  }

  Widget _buildCutoffItem(CutoffDateModel cutoff, int index) {
    final dayFormat = DateFormat('dd');
    final monthFormat = DateFormat('MMM', 'es_MX');

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Date
          SizedBox(
            width: 60,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  dayFormat.format(cutoff.date),
                  style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  monthFormat.format(cutoff.date).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right column: Card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border(
                  left: BorderSide(
                    color: index == 0 ? const Color(0xFF050505) : Colors.black87,
                    width: 6,
                  ),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminCutoffDetailScreen(cutoff: cutoff, index: index),
                    ),
                  ).then((_) {
                    _loadCutoffs();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getCutoffTitle(cutoff),
                              style: const TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${cutoff.paidDrivers.length} Pagaron',
                                  style: TextStyle(color: Colors.green.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  '${cutoff.pendingDrivers.length} Pendientes',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ).animate().fade(duration: 400.ms, delay: (50 * index).ms).slideY(begin: 0.1, end: 0),
    );
  }
}

class CutoffDriverItem {
  final String id;
  final String name;
  final double totalRevenue;
  final double amountDue;
  final bool isPaid;

  CutoffDriverItem({
    required this.id,
    required this.name,
    required this.totalRevenue,
    required this.amountDue,
    required this.isPaid,
  });
}

class CutoffDateModel {
  final String? id;
  final DateTime date;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<CutoffDriverItem> paidDrivers;
  final List<CutoffDriverItem> pendingDrivers;

  CutoffDateModel({
    this.id,
    required this.date,
    this.startDate,
    this.endDate,
    required this.paidDrivers,
    required this.pendingDrivers,
  });
}
