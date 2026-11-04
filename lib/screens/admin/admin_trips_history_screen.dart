import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../models/trip.dart';
import '../trip_detail_screen.dart';

class AdminTripsHistoryScreen extends StatefulWidget {
  const AdminTripsHistoryScreen({super.key});

  @override
  State<AdminTripsHistoryScreen> createState() => _AdminTripsHistoryScreenState();
}

class _AdminTripsHistoryScreenState extends State<AdminTripsHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<dynamic> _trips = [];
  Map<String, String> _userNames = {};
  Map<String, String> _driverNames = {};
  int _rawTripsCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() => _isLoading = true);
    try {
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Obtenemos los viajes con join a la tabla de conductores (si driver_id está en conductores)
      // Nota: asumo que la relación en Supabase permite 'driver:conductores(nombre, apellidos)'
      // Obtenemos los últimos viajes y los filtramos localmente para evitar
      // desajustes de zona horaria entre Supabase (UTC) y el dispositivo local
      final response = await Supabase.instance.client
          .from('trips')
          .select()
          .order('created_at', ascending: false)
          .limit(500);

      final List<dynamic> filteredTrips = (response as List).where((trip) {
        final dateStr = trip['created_at'];
        if (dateStr == null) return false;
        try {
          final dt = DateTime.parse(dateStr).toLocal();
          return dt.year == _selectedDate.year && 
                 dt.month == _selectedDate.month && 
                 dt.day == _selectedDate.day;
        } catch (_) {
          return false;
        }
      }).toList();

      // Cargar nombres de usuarios y conductores para no mostrar IDs sucios
      final userIds = filteredTrips.map((t) => t['user_id']).where((id) => id != null).toSet().toList();
      final driverIds = filteredTrips.map((t) => t['driver_id']).where((id) => id != null).toSet().toList();
      
      final Map<String, String> loadedUsers = {};
      final Map<String, String> loadedDrivers = {};
      
      if (userIds.isNotEmpty) {
        try {
          final usersRes = await Supabase.instance.client.from('users').select('user_id, nombre').inFilter('user_id', userIds);
          for (var u in usersRes) {
            loadedUsers[u['user_id'].toString()] = u['nombre']?.toString() ?? 'Desconocido';
          }
        } catch (_) {}
      }
      
      if (driverIds.isNotEmpty) {
        try {
          final driversRes = await Supabase.instance.client.from('conductores').select('user_id, nombre_completo, nombre').inFilter('user_id', driverIds);
          for (var d in driversRes) {
            loadedDrivers[d['user_id'].toString()] = (d['nombre_completo'] ?? d['nombre'])?.toString() ?? 'Conductor';
          }
        } catch (_) {}
      }

      setState(() {
        _trips = filteredTrips;
        _rawTripsCount = (response as List).length;
        _userNames = loadedUsers;
        _driverNames = loadedDrivers;
      });
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar viajes: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.black,
            colorScheme: const ColorScheme.light(primary: Colors.black, onPrimary: Color(0xFF050505)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTrips();
    }
  }

  String _formatCurrency(num value) {
    return NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 2).format(value);
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '--:--';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final status = (trip['status'] ?? 'N/A').toString().toUpperCase();
    final isCompleted = status == 'COMPLETED';
    final isCancelled = status == 'CANCELLED';
    final fare = (trip['fare'] as num?)?.toDouble() ?? 0.0;
    final driverFare = (trip['total_final'] as num?)?.toDouble() ?? 0.0;
    final method = (trip['metodo_pago'] ?? trip['payment_method'] ?? 'N/A').toString().toUpperCase();
    
    final origin = trip['origin_address']?.toString().isNotEmpty == true ? trip['origin_address'] : 'N/A';
    final destination = trip['destination_address']?.toString().isNotEmpty == true ? trip['destination_address'] : 'N/A';
    final dateStr = trip['created_at'];
    
    final userId = trip['user_id']?.toString() ?? 'N/A';
    final driverId = trip['driver_id']?.toString() ?? 'N/A';
    
    final userName = _userNames[userId] ?? (userId != 'N/A' ? userId.substring(0, 8) : 'N/A');
    final driverName = trip['name_driver'] ?? _driverNames[driverId] ?? 'N/A';

    return GestureDetector(
      onTap: () {
        // Intentar abrir el TripDetailScreen
        try {
          final t = Trip.fromJson(trip);
          Navigator.push(context, MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t)));
        } catch (e) {
          debugPrint('Error al parsear viaje: $e');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STATUS & FECHA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.shade50 : (isCancelled ? Colors.red.shade50 : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green.shade800 : (isCancelled ? Colors.red.shade800 : Colors.black87),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(_formatTime(dateStr), style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // USUARIO Y CONDUCTOR
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pasajero', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('👤 $userName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Conductor', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('🚗 $driverName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ORIGEN Y DESTINO
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: Colors.black87),
                    Container(height: 20, width: 2, color: Colors.grey.shade300),
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(origin, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      Text(destination, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            
            // MONTOS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Viaje', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(_formatCurrency(fare), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ganancia Conductor', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(_formatCurrency(driverFare), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Método', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
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
        title: const Text(
          'Historial de Viajes',
          style: TextStyle(fontFamily: 'Google Sans', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
            tooltip: 'Seleccionar Fecha',
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Fecha Banner
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mostrando viajes del:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      DateFormat('EEEE, d MMMM y', 'es_MX').format(_selectedDate),
                      style: const TextStyle(color: Color(0xFF050505), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.edit_calendar, size: 16, color: Colors.black),
                  label: const Text('Cambiar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF050505),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          // Estadisticas rápidas
          if (!_isLoading && _trips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Total Viajes', _trips.length.toString(), Icons.route),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Completados',
                      _trips.where((t) => t['status'] == 'completed').length.toString(),
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Ingresos',
                      _formatCurrency(_trips.where((t) => t['status'] == 'completed').fold(0.0, (sum, t) => sum + ((t['fare'] as num?)?.toDouble() ?? 0))),
                      Icons.attach_money,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _trips.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay viajes registrados\nen esta fecha',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'Google Sans', fontSize: 16, color: Colors.black54),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '(Supabase devolvió $_rawTripsCount viajes para tu cuenta admin)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _pickDate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: const Color(0xFF050505),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Buscar en otra fecha'),
                            )
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: _trips.length,
                        itemBuilder: (context, index) {
                          return _buildTripCard(_trips[index]).animate().fade(duration: 300.ms, delay: (index * 50).ms).slideY(begin: 0.1, end: 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.black54),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Google Sans', color: color ?? Colors.black)),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }
}
