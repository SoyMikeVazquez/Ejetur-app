import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/trip.dart';
import '../services/driver_profile_service.dart';
import '../services/trip_service.dart';

class ActiveTripSheet extends StatefulWidget {
  final String driverName;
  final String vehicleInfo;
  final String plateNumber;
  final String rating;
  final String etaText;
  final String origin;
  final String destination;
  final Trip? trip;
  final VoidCallback onFinishTrip;

  const ActiveTripSheet({
    super.key,
    this.driverName = 'Roberto Hernández',
    this.vehicleInfo = 'Nissan Versa • Blanco',
    this.plateNumber = 'XYZ-8921',
    this.rating = '4.9',
    this.etaText = 'Llega en ~3 min',
    required this.origin,
    required this.destination,
    this.trip,
    required this.onFinishTrip,
  });

  @override
  State<ActiveTripSheet> createState() => _ActiveTripSheetState();
}

class _ActiveTripSheetState extends State<ActiveTripSheet> {
  String _driverName = '';
  String _vehicleInfo = '';
  String _plateNumber = '';
  String _rating = '5.0';
  String? _driverPhoto;
  bool _isLoadingDriver = true;
  Timer? _cancelTimer;
  bool _canCancelWithoutPenalty = false;
  Timer? _waitTimer;
  int _remainingSeconds = 7 * 60;

  @override
  void initState() {
    super.initState();
    _driverName = widget.driverName;
    _vehicleInfo = widget.vehicleInfo;
    _plateNumber = widget.plateNumber;
    _rating = widget.rating;
    _fetchDriverInfo();
    _startCancelTimer();
    _startWaitTimerIfNeeded();
  }

  @override
  void dispose() {
    _cancelTimer?.cancel();
    _waitTimer?.cancel();
    super.dispose();
  }

  void _startWaitTimerIfNeeded() {
    if (widget.trip?.status == 'arrived') {
      final arrivedAt = widget.trip?.arrivedAt?.toLocal() ?? DateTime.now();
      final now = DateTime.now();
      final diff = now.difference(arrivedAt);
      _remainingSeconds = (7 * 60) - diff.inSeconds;
      
      if (_remainingSeconds <= 0) {
        _waitTimer?.cancel();
        return;
      }
      
      _waitTimer?.cancel();
      _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            timer.cancel();
          }
        });
      });
    } else {
      _waitTimer?.cancel();
      _waitTimer = null;
    }
  }

  void _startCancelTimer() {
    _checkCancelStatus();
    _cancelTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkCancelStatus();
    });
  }

  void _checkCancelStatus() {
    if (widget.trip?.createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(widget.trip!.createdAt!);
      if (difference.inMinutes >= 5) {
        if (!_canCancelWithoutPenalty && mounted) {
          setState(() {
            _canCancelWithoutPenalty = true;
          });
        }
      }
    }
  }

  @override
  void didUpdateWidget(ActiveTripSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip?.driverId != oldWidget.trip?.driverId) {
      _fetchDriverInfo();
    }
    if (widget.trip?.status != oldWidget.trip?.status || widget.trip?.arrivedAt != oldWidget.trip?.arrivedAt) {
      _startWaitTimerIfNeeded();
    }
  }

  Future<void> _fetchDriverInfo() async {
    if (widget.trip?.driverId == null) {
      if (mounted) setState(() => _isLoadingDriver = false);
      return;
    }
    
    final service = DriverProfileService();
    final profile = await service.getDriverProfile(widget.trip!.driverId!);
    
    if (profile != null && mounted) {
      setState(() {
        _driverName = profile['nombre_completo'] ?? profile['nombre'] ?? widget.driverName;
        _driverPhoto = profile['imagen_perfil'] as String?;
        final auto = profile['modelo_auto'] ?? 'Auto';
        final color = profile['color_auto'] ?? '';
        _vehicleInfo = color.isNotEmpty ? '$auto • $color' : auto;
        _plateNumber = profile['placas'] ?? widget.plateNumber;
        _rating = profile['calificacion_promedio']?.toString() ?? profile['calificacion']?.toString() ?? '5.0';
        _isLoadingDriver = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingDriver = false);
    }
  }

  String _getStatusText() {
    if (widget.trip == null) return 'Conductor asignado';
    switch (widget.trip!.status) {
      case 'accepted':
        return 'Conductor en camino';
      case 'arrived':
        return '¡El conductor ha llegado!';
      case 'in_progress':
        return 'Viaje en curso';
      default:
        return 'Conductor asignado';
    }
  }

  Color _getStatusColor() {
    if (widget.trip == null) return Colors.black;
    switch (widget.trip!.status) {
      case 'accepted':
        return Colors.black; // Normal
      case 'arrived':
        return Colors.orange[800]!; // Llamativo, llegó
      case 'in_progress':
        return Colors.blue[700]!; // Viaje activo
      default:
        return Colors.black;
    }
  }

  void _showSecurityModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.shield, color: Colors.green, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Centro de Seguridad',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Opcion 1: Compartir viaje
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.blueAccent),
                ),
                title: const Text('Compartir mi viaje', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Envía un enlace de seguimiento en vivo por WhatsApp o mensaje'),
                onTap: () {
                  Navigator.pop(context);
                  _showSharePreviewDialog(context);
                },
              ),

              const Divider(),

              // Opcion 2: Llamada de emergencia 911
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_police, color: Colors.redAccent),
                ),
                title: const Text('Asistencia 911', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                subtitle: const Text('Llama a los servicios de emergencia locales'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Conectando con emergencia 911...'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSharePreviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mark_chat_read, color: Colors.green),
              SizedBox(width: 8),
              Text('Vista Previa del Enlace'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este es el mensaje de seguimiento que recibirán tus familiares:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  '🚗 Sigue mi viaje en vivo en Taxiseguro con $_driverName ($_vehicleInfo, Placas $_plateNumber).\n\n📍 Destino: ${widget.destination}\n🔗 https://taxiseguro.app/track/trip_demo_123',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('¡Enlace de seguimiento compartido!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Compartir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 15,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // Top Status & ETA Banner
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.etaText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isLoadingDriver ? '...' : _plateNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),

            if (widget.trip?.codigo != null || widget.trip?.status == 'arrived') ...[
              const SizedBox(height: 12),
              _buildUberPinBanner(widget.trip?.codigo),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            
            if (widget.trip?.status == 'arrived') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _remainingSeconds < 60 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _remainingSeconds < 60 ? Colors.red : Colors.orange),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: _remainingSeconds < 60 ? Colors.red : Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tiempo de espera restante: ${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds < 60 ? Colors.red : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'El viaje se cancelará si no subes antes de este tiempo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black54),
                ),
              ),
            ],
            
            const SizedBox(height: 16),

            // Driver & Vehicle Card
            Row(
              children: [
                // Driver Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _driverPhoto != null && _driverPhoto!.isNotEmpty
                      ? NetworkImage(_driverPhoto!)
                      : null,
                  child: _driverPhoto == null || _driverPhoto!.isEmpty
                      ? const Icon(Icons.person, size: 36, color: Colors.black54)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isLoadingDriver ? 'Cargando...' : _driverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            _isLoadingDriver ? '-' : _rating,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingDriver ? 'Buscando información...' : _vehicleInfo,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Actions (Call, Message, Share)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.phone,
                  label: 'Llamar',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Llamando al conductor...')),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Mensaje',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abriendo chat...')),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.shield_outlined,
                  label: 'Seguridad',
                  onTap: () => _showSecurityModal(context),
                ),
              ],
            ),

            if (_canCancelWithoutPenalty && widget.trip != null && widget.trip!.status == 'accepted') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelTripByPassenger(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Cancelar Viaje (Sin Penalización)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

  void _cancelTripByPassenger(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Cancelar Viaje?'),
          content: const Text('Han pasado más de 5 minutos, por lo que puedes cancelar sin penalización.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mantener Viaje'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                if (widget.trip?.id != null) {
                  final service = TripService();
                  await service.cancelTrip(widget.trip!.id!, cancelReason: 'Cancelado por el pasajero después de 5 minutos');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Viaje cancelado exitosamente.')),
                    );
                  }
                }
              },
              child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUberPinBanner(int? pinCode) {
    final pinString = pinCode?.toString().padLeft(5, '0');
    final digits = pinString?.split('') ?? ['•', '•', '•', '•', '•'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FF), // Fondo celeste pastel idéntico a Uber
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E6FF), width: 1),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'PIN de este viaje',
              style: TextStyle(
                fontFamily: 'Google Sans',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          // Dígitos individuales en cajitas azules redondeadas estilo Uber
          Row(
            mainAxisSize: MainAxisSize.min,
            children: digits.map((digit) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 28,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF), // Azul Uber vibrante
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.28),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  digit,
                  style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 10),
          // Botón de altavoz / copiar PIN
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (pinString == null) return;
                Clipboard.setData(ClipboardData(text: pinString));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('PIN copiado al portapapeles: $pinString'),
                      ],
                    ),
                    backgroundColor: const Color(0xFF007AFF),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: Color(0xFF007AFF),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
