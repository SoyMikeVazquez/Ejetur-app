import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/admin_service.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadPendingDrivers();
  }

  Future<void> _loadPendingDrivers() async {
    setState(() => _isLoading = true);
    final drivers = await _adminService.getPendingDrivers();
    if (mounted) {
      setState(() {
        _pendingDrivers = drivers;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDecision(String userId, String driverName, bool approve) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(approve ? '¿Aprobar conductor?' : '¿Rechazar solicitud?'),
        content: Text(
          approve
              ? 'El conductor "$driverName" tendrá acceso inmediato para recibir viajes y conectarse a la plataforma.'
              : 'La solicitud de "$driverName" será marcada como No Aprobada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? const Color(0xFF050505) : Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(approve ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final error = await _adminService.setDriverApproval(userId, approve: approve);
      if (mounted) {
        if (error != null) {
          // Mostrar error exacto
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Error en la base de datos'),
              content: Text(error),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                )
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve ? 'Conductor aprobado con éxito' : 'Solicitud rechazada y eliminada'),
              backgroundColor: approve ? Colors.green : Colors.black87,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadPendingDrivers();
      }
    }
  }

  void _showDocumentViewer(String title, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay imagen disponible para este documento')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    backgroundColor: Colors.black87,
                    title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: Color(0xFF050505)),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('Error al cargar documento', style: TextStyle(color: Colors.white70)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Aprobación de Conductores',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadPendingDrivers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _pendingDrivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 72, color: Colors.green.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        '¡Todo al día!',
                        style: TextStyle(fontFamily: 'Google Sans', fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No hay solicitudes pendientes de revisión.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _pendingDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _pendingDrivers[index];
                    final userId = driver['user_id']?.toString() ?? driver['id']?.toString() ?? '';
                    final name = driver['nombre_completo'] ?? driver['nombre'] ?? 'Conductor';
                    final phone = driver['telefono'] ?? 'Sin teléfono';
                    final email = driver['correo'] ?? '';
                    final auto = '${driver['modelo_auto'] ?? 'Auto'} • ${driver['color_auto'] ?? ''} (${driver['placas'] ?? 'S/P'})';
                    final banco = '${driver['banco'] ?? 'Banco'} • CLABE: ${driver['clabe'] ?? 'N/A'}';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
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
                          // Header con estado
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.pending_actions, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pendiente de Aprobación',
                                  style: TextStyle(
                                    fontFamily: 'Google Sans',
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  phone,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54, fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Google Sans',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(email, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                const SizedBox(height: 14),

                                // Fila de Auto
                                _buildInfoPill(Icons.directions_car, auto),
                                const SizedBox(height: 8),

                                // Fila de Banco
                                _buildInfoPill(Icons.account_balance, banco),
                                const SizedBox(height: 18),

                                // Documentos Requeridos
                                const Text(
                                  'Documentos Adjuntos (Toca para inspeccionar):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildDocButton('INE', driver['ine_url']),
                                    _buildDocButton('Licencia', driver['licencia_url']),
                                    _buildDocButton('Seguro', driver['seguro_url']),
                                    _buildDocButton('Circulación', driver['tarjeta_circulacion_url']),
                                  ],
                                ),

                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 12),

                                // Botones de Acción
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _handleDecision(userId, name, false),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Text(
                                          'Rechazar',
                                          style: TextStyle(
                                            fontFamily: 'Google Sans',
                                            fontWeight: FontWeight.bold,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _handleDecision(userId, name, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF050505), // Modern Black
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        child: const Text(
                                          'Aprobar Conductor',
                                          style: TextStyle(
                                            fontFamily: 'Google Sans',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 400.ms, delay: (index * 80).ms).slideY(begin: 0.1, end: 0);
                  },
                ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocButton(String label, String? url) {
    final bool hasDoc = url != null && url.isNotEmpty;

    return ActionChip(
      avatar: Icon(
        hasDoc ? Icons.check_circle : Icons.error_outline,
        size: 16,
        color: hasDoc ? Colors.green : Colors.grey,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: hasDoc ? Colors.black87 : Colors.grey,
        ),
      ),
      backgroundColor: hasDoc ? Colors.grey.shade100 : Colors.grey.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: hasDoc ? () => _showDocumentViewer(label, url) : null,
    );
  }
}
