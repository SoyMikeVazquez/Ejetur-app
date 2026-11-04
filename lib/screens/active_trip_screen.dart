import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/trip.dart';
import '../services/trip_service.dart';
import '../services/location_service.dart';
import '../services/background_service.dart';
import '../env/env.dart';
import '../services/rating_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class ActiveTripScreen extends StatefulWidget {
  final Trip trip;

  const ActiveTripScreen({super.key, required this.trip});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}
class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final TripService _tripService = TripService();
  late Trip _currentTrip;
  bool _isLoading = false;
  List<LatLng> _routePoints = [];
  LatLng? _driverLocation;
  final MapController _mapController = MapController();
  StreamSubscription<Trip?>? _tripSubscription;
  Timer? _waitTimer;
  int _remainingSeconds = 7 * 60;

  Map<String, dynamic>? _passengerInfo;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _fetchRoute();
    _listenToTripUpdates();
    _loadPassengerInfo();
    _startWaitTimerIfNeeded();
    _ensureTripCodeIfArrived();
  }

  void _ensureTripCodeIfArrived() {
    if (_currentTrip.status == 'arrived' && _currentTrip.codigo == null && _currentTrip.id != null && _currentTrip.id != 'simulated_trip_123') {
      final pinCode = 10000 + Random().nextInt(90000);
      _tripService.updateTripStatus(_currentTrip.id!, 'arrived', codigo: pinCode).then((success) {
        if (success && mounted) {
          setState(() {
            _currentTrip = _currentTrip.copyWith(codigo: pinCode);
          });
        }
      });
    }
  }

  void _startWaitTimerIfNeeded() {
    if (_currentTrip.status == 'arrived') {
      final arrivedAt = _currentTrip.arrivedAt?.toLocal() ?? DateTime.now();
      final now = DateTime.now();
      final diff = now.difference(arrivedAt);
      _remainingSeconds = (7 * 60) - diff.inSeconds;
      
      if (_remainingSeconds <= 0) {
        _cancelTripDueToTimeout();
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
            _cancelTripDueToTimeout();
          }
        });
      });
    } else {
      _waitTimer?.cancel();
      _waitTimer = null;
    }
  }

  Future<void> _cancelTripDueToTimeout() async {
    if (_currentTrip.id == null || _currentTrip.status == 'cancelled') return;
    await _tripService.updateTripStatus(_currentTrip.id!, 'cancelled');
    BackgroundServiceHelper.stopDriverTrip();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje cancelado: tiempo de espera de 7 min excedido.'), backgroundColor: Colors.red),
      );
      Navigator.of(context).popUntil((route) => route.isFirst); 
    }
  }

  Future<void> _loadPassengerInfo() async {
    if (_currentTrip.userId.isNotEmpty && _currentTrip.id != 'simulated_trip_123') {
      try {
        final info = await _tripService.getPassengerPublicInfo(_currentTrip.userId);
        if (mounted) {
          setState(() {
            _passengerInfo = info;
          });
        }
      } catch (e) {
        debugPrint('Error cargando info del pasajero: $e');
      }
    }
  }

  void _listenToTripUpdates() {
    if (_currentTrip.id == null || _currentTrip.id == 'simulated_trip_123') return;
    
    _tripSubscription = _tripService.streamTrip(_currentTrip.id!).listen((trip) {
      if (trip != null && mounted) {
        if (trip.status == 'cancelled' && _currentTrip.status != 'cancelled') {
          // El pasajero canceló el viaje
          BackgroundServiceHelper.showAlertNotification('Viaje Cancelado', 'El pasajero ha cancelado el viaje.');
          BackgroundServiceHelper.updateDriverTripStatus('Viaje Cancelado', 'El pasajero ha cancelado el viaje');
          _showTripCancelledDialog();
        } else {
          setState(() {
            _currentTrip = trip;
          });
          _startWaitTimerIfNeeded();
        }
      }
    });
  }

  void _showTripCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Viaje Cancelado', style: TextStyle(color: Colors.red)),
        content: const Text('El pasajero ha cancelado el viaje. Serás redirigido al inicio.'),
        actions: [
          TextButton(
            onPressed: () {
              BackgroundServiceHelper.stopDriverTrip();
              Navigator.of(context).popUntil((route) => route.isFirst); // Close dialog and return to main screen
            },
            child: const Text('Entendido', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _tripSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchRoute() async {
    final locationService = LocationService();
    final driverLoc = await locationService.getCurrentLocation();
    if (mounted && driverLoc != null) {
      setState(() {
        _driverLocation = driverLoc;
      });
    }

    double lat1, lng1, lat2, lng2;

    if (_currentTrip.status == 'accepted' || _currentTrip.status == 'arrived') {
      // Driver navigating to passenger pickup
      lat1 = driverLoc?.latitude ?? (_currentTrip.originLat ?? 19.4326);
      lng1 = driverLoc?.longitude ?? (_currentTrip.originLng ?? -99.1332);
      // Si no hay destino, usa el origen o la ubicación del driver
      lat2 = _currentTrip.originLat ?? 19.4326;
      lng2 = _currentTrip.originLng ?? -99.1332;
    } else {
      // Driver navigating to destination
      lat1 = _currentTrip.originLat ?? 19.4326; 
      lng1 = _currentTrip.originLng ?? -99.1332;
      if (driverLoc != null) {
        lat1 = driverLoc.latitude;
        lng1 = driverLoc.longitude;
      }
      lat2 = _currentTrip.destinationLat ?? lat1;
      lng2 = _currentTrip.destinationLng ?? lng1;
    }

    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$lng1,$lat1;$lng2,$lat2?geometries=geojson');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          if (mounted) {
            final points = geometry.map((coord) => LatLng(coord[1] as double, coord[0] as double)).toList();
            setState(() {
              _routePoints = points;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching route: $e');
    }

    // Siempre intentar ajustar la cámara, ya sea con los puntos de la ruta o con los marcadores
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          List<LatLng> boundsPoints = _routePoints.isNotEmpty ? _routePoints : [LatLng(lat1, lng1), LatLng(lat2, lng2)];
          
          // Si los puntos son exactamente los mismos, añadir un offset mínimo para que no colapse
          if (boundsPoints.length == 2 && boundsPoints[0].latitude == boundsPoints[1].latitude && boundsPoints[0].longitude == boundsPoints[1].longitude) {
            boundsPoints.add(LatLng(lat1 + 0.005, lng1 + 0.005));
            boundsPoints.add(LatLng(lat1 - 0.005, lng1 - 0.005));
          }

          final bounds = LatLngBounds.fromPoints(boundsPoints);
          if (bounds.north != bounds.south || bounds.east != bounds.west) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.only(top: 80.0, left: 50.0, right: 50.0, bottom: 350.0), // Padding extra abajo por el BottomSheet
                maxZoom: 16.5,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error fitting camera: $e');
        }
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_currentTrip.id == null) return;
    
    setState(() => _isLoading = true);
    int? codeToUse = _currentTrip.codigo;
    if (newStatus == 'arrived' && codeToUse == null) {
      codeToUse = 10000 + Random().nextInt(90000);
    }

    bool success = true;
    if (_currentTrip.id != 'simulated_trip_123') {
      success = await _tripService.updateTripStatus(
        _currentTrip.id!,
        newStatus,
        codigo: codeToUse,
      );
    }
    
    if (success) {
      if (newStatus == 'arrived') {
        BackgroundServiceHelper.updateDriverTripStatus('Has llegado', 'Esperando al pasajero');
      } else if (newStatus == 'in_progress') {
        BackgroundServiceHelper.updateDriverTripStatus('Viaje en curso', 'Dirigiéndote al destino');
      } else if (newStatus == 'completed') {
        BackgroundServiceHelper.stopDriverTrip();
      }

      setState(() {
        _currentTrip = _currentTrip.copyWith(
          status: newStatus,
          arrivedAt: newStatus == 'arrived' ? DateTime.now() : _currentTrip.arrivedAt,
          codigo: codeToUse ?? _currentTrip.codigo,
        );
      });
      _startWaitTimerIfNeeded();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al actualizar el estado del viaje'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  void _promptTripPin() {
    if (_currentTrip.codigo == null) {
      // Si por alguna razón no tiene código registrado, permite iniciar directamente
      _updateStatus('in_progress');
      return;
    }

    final String expectedPin = _currentTrip.codigo.toString().padLeft(5, '0');
    final TextEditingController pinController = TextEditingController();
    final FocusNode pinFocusNode = FocusNode();
    String errorMessage = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final enteredPin = pinController.text;
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 15,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 20,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBF3FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 30,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ingresa el PIN de seguridad',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pídele al pasajero el código de 5 dígitos que aparece en su aplicación para iniciar el viaje.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Cajitas de PIN interactivas
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => pinFocusNode.requestFocus(),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final hasDigit = index < enteredPin.length;
                        final isCurrent = index == enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 48,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hasDigit ? const Color(0xFF007AFF) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF007AFF)
                                  : (hasDigit ? const Color(0xFF007AFF) : const Color(0xFFE5E7EB)),
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            hasDigit ? enteredPin[index] : '',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: hasDigit ? Colors.white : Colors.black87,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Campo de texto invisible para teclear con teclado numérico
                  Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      height: 1,
                      child: TextField(
                        controller: pinController,
                        focusNode: pinFocusNode,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        onChanged: (val) {
                          setModalState(() {
                            errorMessage = '';
                          });
                          if (val.length == 5) {
                            if (val == expectedPin) {
                              Navigator.pop(ctx);
                              _updateStatus('in_progress');
                            } else {
                              setModalState(() {
                                errorMessage = 'PIN incorrecto. Por favor verifica con el pasajero.';
                              });
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  if (kDebugMode || _currentTrip.id == 'simulated_trip_123') ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'PIN para pruebas: $expectedPin',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Botón Iniciar
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: enteredPin.length == 5
                          ? () {
                              if (enteredPin == expectedPin) {
                                Navigator.pop(ctx);
                                _updateStatus('in_progress');
                              } else {
                                setModalState(() {
                                  errorMessage = 'PIN incorrecto. Por favor verifica con el pasajero.';
                                });
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF050505), // Modern Black
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: Colors.grey[400],
                      ),
                      child: const Text(
                        'Verificar e Iniciar Viaje',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Botón omitir con advertencia
                  TextButton(
                    onPressed: () {
                      _showBypassPinConfirmation(ctx);
                    },
                    child: const Text(
                      'Iniciar viaje sin PIN',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black45,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBypassPinConfirmation(BuildContext parentCtx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Iniciar sin código?',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Inicia sin PIN únicamente si el pasajero no tiene acceso a su teléfono o la app se encuentra temporalmente inaccesible.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Cierra diálogo
              Navigator.pop(parentCtx); // Cierra bottom sheet del PIN
              _updateStatus('in_progress');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Iniciar de todos modos'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          'Cancelar Viaje',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Por favor, indica el motivo de la cancelación:',
              style: TextStyle(fontFamily: 'Inter', color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Motivo...',
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver', style: TextStyle(fontFamily: 'Google Sans', color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Debes ingresar un motivo')));
                return;
              }
              Navigator.pop(ctx);
              _cancelTrip(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('Cancelar Viaje', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String?>> _getDriverInfo() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return {'name': null, 'photo': null};
    return await _tripService.getDriverPublicInfo(user.id);
  }

  Future<void> _cancelTrip(String reason) async {
    if (_currentTrip.id == null) return;
    setState(() => _isLoading = true);
    
    bool success = true;
    if (_currentTrip.id != 'simulated_trip_123') {
      final driverInfo = await _getDriverInfo();
      final finalReason = reason.trim().isNotEmpty ? reason.trim() : 'Cancelado por el conductor';
      success = await _tripService.cancelTrip(
        _currentTrip.id!,
        cancelReason: finalReason,
        nameDriver: driverInfo['name'],
        photoDriver: driverInfo['photo'],
      );
    }
    
    setState(() => _isLoading = false);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viaje cancelado')));
        Navigator.of(context).popUntil((route) => route.isFirst); // Regresar al home de forma segura
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cancelar el viaje'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _openMapApp(String appType, bool toOrigin) async {
    final lat = toOrigin ? (_currentTrip.originLat ?? 19.4326) : (_currentTrip.destinationLat ?? _currentTrip.originLat ?? 19.4326);
    final lng = toOrigin ? (_currentTrip.originLng ?? -99.1332) : (_currentTrip.destinationLng ?? _currentTrip.originLng ?? -99.1332);
    
    Uri? url;
    if (appType == 'waze') {
      url = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
    } else if (appType == 'google') {
      url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    }

    if (url != null) {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo abrir $appType. Asegúrate de tener la app instalada.')),
          );
        }
      }
    }
  }

  void _showPaymentBottomSheet() {
    double fareAmount = _currentTrip.fare ?? 0.0;

    if (_currentTrip.paymentMethod == 'tarjeta') {
      _showReviewBottomSheet(fareAmount);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            boxShadow: [
              BoxShadow(color: Color(0x1F000000), blurRadius: 15, offset: Offset(0, -4)),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 32,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Icon(Icons.payments, size: 64, color: Color(0xFF050505)),
              const SizedBox(height: 16),
              const Text(
                'Cobro en Efectivo',
                style: TextStyle(fontFamily: 'Google Sans', fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Por favor, cobra al pasajero la siguiente cantidad:',
                style: TextStyle(fontFamily: 'Inter', color: Colors.black54, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                '\$${fareAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontFamily: 'Google Sans', fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showReviewBottomSheet(fareAmount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF050505), // Modern Black
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    'Pago Finalizado',
                    style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewBottomSheet(double finalFare) {
    int rating = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [
                  BoxShadow(color: Color(0x1F000000), blurRadius: 15, offset: Offset(0, -4)),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    '¡Viaje Finalizado!',
                    style: TextStyle(fontFamily: 'Google Sans', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Califica a tu pasajero',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: const Color(0xFF050505),
                          size: 40,
                        ),
                        onPressed: () {
                          setModalState(() {
                            rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _completeTripFinal(finalFare, passengerRating: rating);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF050505),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Finalizar', style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Future<void> _completeTripFinal(double fare, {int passengerRating = 5}) async {
    if (_currentTrip.id == null) return;
    
    setState(() => _isLoading = true);
    bool success = true;
    if (_currentTrip.id != 'simulated_trip_123') {
      final driverInfo = await _getDriverInfo();
      success = await _tripService.completeTrip(
        _currentTrip.id!,
        fare,
        nameDriver: driverInfo['name'],
        photoDriver: driverInfo['photo'],
      );

      // Guardar calificación al pasajero en Supabase
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId != null && _currentTrip.userId.isNotEmpty) {
        try {
          final ratingService = RatingService();
          await ratingService.submitRating(
            tripId: _currentTrip.id!,
            reviewerId: currentUserId,
            targetId: _currentTrip.userId,
            role: 'passenger',
            rating: passengerRating.toDouble(),
          );
        } catch (e) {
          debugPrint('Error guardando rating del pasajero: $e');
        }
      }
    }
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Viaje finalizado con éxito'), backgroundColor: Colors.green),
        );
        Navigator.of(context).popUntil((route) => route.isFirst); // Regresa al dashboard seguro
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al finalizar el viaje'), backgroundColor: Colors.red),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Modo Viaje';
    String actionText = '';
    VoidCallback? actionCallback;
    IconData actionIcon = Icons.navigation;
    
    String origin = _currentTrip.originAddress;
    String destination = _currentTrip.destinationAddress;

    double lat1, lng1, lat2, lng2;
    if (_currentTrip.status == 'accepted' || _currentTrip.status == 'arrived') {
      lat1 = _driverLocation?.latitude ?? (_currentTrip.originLat ?? 19.4326);
      lng1 = _driverLocation?.longitude ?? (_currentTrip.originLng ?? -99.1332);
      lat2 = _currentTrip.originLat ?? 19.4326;
      lng2 = _currentTrip.originLng ?? -99.1332;
    } else {
      lat1 = _currentTrip.originLat ?? 19.4326;
      lng1 = _currentTrip.originLng ?? -99.1332;
      if (_driverLocation != null) {
        lat1 = _driverLocation!.latitude;
        lng1 = _driverLocation!.longitude;
      }
      lat2 = _currentTrip.destinationLat ?? lat1;
      lng2 = _currentTrip.destinationLng ?? lng1;
    }

    switch (_currentTrip.status) {
      case 'accepted':
        title = 'Navegar al punto';
        actionText = 'Llegué al punto de recogida';
        actionIcon = Icons.location_on;
        actionCallback = () => _updateStatus('arrived');
        break;
      case 'arrived':
        title = 'Esperando Pasajero';
        actionText = 'Iniciar viaje';
        actionIcon = Icons.play_arrow;
        actionCallback = _promptTripPin;
        break;
      case 'in_progress':
        title = 'Navegando al Destino';
        actionText = 'Finalizar viaje';
        actionIcon = Icons.stop;
        actionCallback = _showPaymentBottomSheet;
        break;
      default:
        title = 'Viaje completado';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Google Sans',
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mapa en Modo Oscuro (dark-v11)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(lat1, lng1),
                initialZoom: 15.0,
                maxZoom: 18.0,
                minZoom: 2.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=${Env.mapboxApiKey}',
                  userAgentPackageName: 'com.taxiseguro.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.black.withValues(alpha: 0.8),
                      strokeWidth: 7.0,
                    ),
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFFFFD700), // Amarillo brillante
                      strokeWidth: 4.5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat1, lng1),
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700), // Amarillo
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.my_location, color: Colors.black, size: 22),
                      ),
                    ),
                    Marker(
                      point: LatLng(lat2, lng2),
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Panel Inferior Deslizable
          DraggableScrollableSheet(
            initialChildSize: 0.35, // Ocupa el 35% de la pantalla inicialmente
            minChildSize: 0.20,     // Puede colapsarse hasta el 20%
            maxChildSize: 0.65,     // Puede expandirse hasta el 65%
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(color: Color(0x29000000), blurRadius: 20, offset: Offset(0, -6)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Handle Bar
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                    // Tarjeta del Pasajero (Nombre, Foto, Calificación)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x0F000000)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _passengerInfo?['photo'] != null && (_passengerInfo!['photo'] as String).isNotEmpty
                                ? NetworkImage(_passengerInfo!['photo'])
                                : null,
                            child: _passengerInfo?['photo'] == null || (_passengerInfo!['photo'] as String).isEmpty
                                ? const Icon(Icons.person, color: Colors.black54, size: 26)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _passengerInfo?['name'] ?? 'Pasajero',
                                  style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      (_passengerInfo?['rating'] as num?)?.toStringAsFixed(1) ?? '5.0',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${_passengerInfo?['totalRatings'] ?? 0} viajes)',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Detalles de Origen y Destino
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F3F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.my_location, color: Colors.black, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Punto de recogida',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                origin,
                                style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 17),
                      child: SizedBox(
                        height: 18,
                        child: VerticalDivider(color: Colors.black12, thickness: 2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF3F3F3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Destino',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                destination,
                                style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Temporizador (Solo en 'arrived' - Esperando Pasajero)
                    if (_currentTrip.status == 'arrived') ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _remainingSeconds < 60 ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _remainingSeconds < 60 ? Colors.red : Colors.orange),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer, color: _remainingSeconds < 60 ? Colors.red : Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontFamily: 'Google Sans',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _remainingSeconds < 60 ? Colors.red : Colors.orange[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Si el pasajero no llega en este tiempo, el viaje se cancelará automáticamente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Botones de Contacto (Solo en 'arrived' - Esperando Pasajero)
                    if (_currentTrip.status == 'arrived') ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  final phone = _passengerInfo?['phone'];
                                  if (phone != null && phone.toString().isNotEmpty) {
                                    final Uri url = Uri.parse('tel:$phone');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                      return;
                                    }
                                  }
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Número de teléfono del pasajero no disponible.')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.phone, size: 20),
                                label: const Text('Llamar', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F3F3),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('La función de chat se implementará pronto.')),
                                  );
                                },
                                icon: const Icon(Icons.message, size: 20),
                                label: const Text('Mensaje', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F3F3),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // Botones de Navegación Externa (Google Maps / Waze) estilo Píldora
                    if (_currentTrip.status == 'accepted' || _currentTrip.status == 'arrived' || _currentTrip.status == 'in_progress') ...[
                      const Text(
                        'Navegar usando:',
                        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => _openMapApp('google', _currentTrip.status != 'in_progress'),
                                icon: const Icon(Icons.map, color: Colors.black, size: 18),
                                label: const Text(
                                  'Google Maps',
                                  style: TextStyle(fontFamily: 'Google Sans', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black12, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => _openMapApp('waze', _currentTrip.status != 'in_progress'),
                                icon: const Icon(Icons.navigation, color: Colors.black, size: 18),
                                label: const Text(
                                  'Waze',
                                  style: TextStyle(fontFamily: 'Google Sans', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.black12, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Botón de Acción Principal en Electric Green con Radio 30
                    if (actionText.isNotEmpty)
                      SizedBox(
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : actionCallback,
                          icon: _isLoading 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Icon(actionIcon, size: 24),
                          label: Text(
                            actionText,
                            style: const TextStyle(fontFamily: 'Google Sans', fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF050505), // Modern Black
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      
                    if (_currentTrip.status != 'completed' && _currentTrip.status != 'cancelled') ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading ? null : _showCancelDialog,
                        child: const Text(
                          'Cancelar Viaje',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
      ),
    );
  }
}
