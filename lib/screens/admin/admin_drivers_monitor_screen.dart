import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/admin_service.dart';
import 'admin_driver_detail_screen.dart';
import 'admin_driver_registration_screen.dart';

class AdminDriversMonitorScreen extends StatefulWidget {
  const AdminDriversMonitorScreen({super.key});

  @override
  State<AdminDriversMonitorScreen> createState() => _AdminDriversMonitorScreenState();
}

class _AdminDriversMonitorScreenState extends State<AdminDriversMonitorScreen> {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _drivers = [];
  String _selectedFilter = 'todos'; // 'todos', 'activos', 'pendientes', 'inactivos'

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    final list = await _adminService.getAllDrivers();
    if (mounted) {
      setState(() {
        _drivers = list;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredDrivers {
    List<Map<String, dynamic>> list;
    if (_selectedFilter == 'todos') {
      list = List<Map<String, dynamic>>.from(_drivers);
    } else {
      list = _drivers.where((d) {
        final isActivo = d['isActivo'] == true;
        final aprobacion = (d['Aprobación'] ?? d['Aprobacion'] ?? d['aprobacion'] ?? '').toString().toLowerCase().trim();

        if (_selectedFilter == 'activos') return isActivo;
        if (_selectedFilter == 'pendientes') return aprobacion == 'pendiente';
        if (_selectedFilter == 'inactivos') return !isActivo && aprobacion != 'pendiente';
        return true;
      }).toList();
    }

    // Ordenar: primero los activos y después los no activos, luego alfabéticamente
    list.sort((a, b) {
      final aActive = a['isActivo'] == true;
      final bActive = b['isActivo'] == true;
      
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;

      // Si ambos tienen el mismo estado, ordenamos alfabéticamente
      final nameA = (a['nombre_completo'] ?? a['nombre'] ?? 'Conductor').toString().toLowerCase();
      final nameB = (b['nombre_completo'] ?? b['nombre'] ?? 'Conductor').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDrivers;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Monitor de Conductores',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
            child: IconButton(
              icon: const Icon(Icons.person_add, color: Colors.black, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDriverRegistrationScreen()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _loadDrivers,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Column(
              children: [
                // 1. Filtros de Conductores
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildFilterChip('Todos (${_drivers.length})', 'todos'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Activos', 'activos'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pendientes Aprobación', 'pendientes'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Inactivos', 'inactivos'),
                    ],
                  ),
                ),

                // 3. Lista de Conductores
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No hay conductores en esta categoría'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final driver = filtered[index];
                            final name = driver['nombre_completo'] ?? driver['nombre'] ?? 'Conductor';
                            final auto = '${driver['modelo_auto'] ?? 'Auto'} (${driver['placas'] ?? 'S/P'})';
                            final phone = driver['telefono'] ?? 'Sin teléfono';
                                                        final aprobacion = (driver['Aprobación'] ?? driver['Aprobacion'] ?? driver['aprobacion'] ?? '').toString();

                            final bool isAct = driver['isActivo'] == true;
                            final bool isPend = aprobacion.toLowerCase() == 'pendiente';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isAct
                                          ? const Color(0xFF050505).withValues(alpha: 0.2)
                                          : isPend
                                              ? Colors.amber.withValues(alpha: 0.2)
                                              : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.local_taxi,
                                      color: isAct ? Colors.black : isPend ? Colors.amber.shade900 : Colors.grey,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$auto • $phone', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isAct ? Colors.green.shade100 : isPend ? Colors.amber.shade100 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              isAct ? 'ACTIVO' : isPend ? 'PENDIENTE' : 'INACTIVO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isAct ? Colors.green.shade900 : isPend ? Colors.amber.shade900 : Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black38),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AdminDriverDetailScreen(driver: driver)),
                                    ).then((_) => _loadDrivers());
                                  },
                                ),
                              ),
                            ).animate().fade(duration: 300.ms, delay: (index * 40).ms).slideY(begin: 0.05, end: 0);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Google Sans',
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.black87,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF050505),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
        }
      },
    );
  }
}
