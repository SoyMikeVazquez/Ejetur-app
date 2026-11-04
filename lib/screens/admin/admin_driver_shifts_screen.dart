import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/driver_shift_service.dart';

class AdminDriverShiftsScreen extends StatefulWidget {
  final DriverShiftStats shiftStats;
  final String driverName;

  const AdminDriverShiftsScreen({
    super.key,
    required this.shiftStats,
    required this.driverName,
  });

  @override
  State<AdminDriverShiftsScreen> createState() => _AdminDriverShiftsScreenState();
}

class _AdminDriverShiftsScreenState extends State<AdminDriverShiftsScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Buscar si hay jornadas en la fecha seleccionada
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    // Encontrar el DailyShiftSummary correspondiente a _selectedDate
    DailyShiftSummary? selectedDaySummary;
    for (var day in widget.shiftStats.daysHistory) {
      if (day.fecha == selectedDateStr) {
        selectedDaySummary = day;
        break;
      }
    }

    final sessions = selectedDaySummary?.sesiones ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          children: [
            const Text(
              'Jornadas y Horarios',
              style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black, fontSize: 18),
            ),
            Text(
              widget.driverName,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.black, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF050505).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _pickDate(context),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header de la fecha seleccionada
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mostrando actividad del:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'es_MX').format(_selectedDate),
                      style: const TextStyle(
                        fontFamily: 'Google Sans',
                        color: Color(0xFF050505),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                if (selectedDaySummary != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMetric(Icons.timer, 'Tiempo Total', selectedDaySummary.formattedTime),
                      const SizedBox(width: 24),
                      _buildMetric(Icons.login, 'Sesiones', '${sessions.length} conex.'),
                    ],
                  ),
                ]
              ],
            ),
          ),

          // Lista de sesiones del día
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bedtime_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'No hubo actividad en este día',
                          style: TextStyle(fontFamily: 'Google Sans', fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El conductor no se conectó a la app.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _pickDate(context),
                          icon: const Icon(Icons.search, color: Colors.black),
                          label: const Text('Buscar en otra fecha', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF050505),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        )
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Icono de estado
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: session.isOngoing ? Colors.green.shade50 : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                session.isOngoing ? Icons.cell_wifi : Icons.power_settings_new,
                                color: session.isOngoing ? Colors.green : Colors.grey.shade600,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Tiempos
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('hh:mm a').format(session.horaConexion),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                                      ),
                                      Text(
                                        session.horaDesconexion != null
                                            ? DateFormat('hh:mm a').format(session.horaDesconexion!)
                                            : 'En curso',
                                        style: TextStyle(
                                          fontWeight: session.isOngoing ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 15,
                                          color: session.isOngoing ? Colors.green : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    session.isOngoing ? 'Sesión activa actualmente' : 'Sesión finalizada',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Duración
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${session.minutosActivo}m',
                                style: const TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        )
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final initialDate = widget.shiftStats.daysHistory.isNotEmpty 
        ? DateTime.parse(widget.shiftStats.daysHistory.first.fecha) 
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Color(0xFF050505),
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.black),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
}
