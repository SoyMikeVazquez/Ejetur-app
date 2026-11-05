import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/mapbox_service.dart';
import '../services/location_service.dart';
import '../env/env.dart';
import 'dart:math';

class SimulatedCar {
  LatLng position;
  double heading;
  LatLng destination;

  SimulatedCar({required this.position, required this.heading, required this.destination});
}
class MapWidget extends StatefulWidget {
  final LatLng? originLatLng;
  final String? destination;
  final LatLng? destinationLatLng;
  final bool isPinPickerMode;
  final Function(LatLng center)? onCameraMove;
  final Function(double distanceMeters, double durationSeconds)? onRouteCalculated;

  const MapWidget({
    super.key,
    this.originLatLng,
    this.destination,
    this.destinationLatLng,
    this.isPinPickerMode = false,
    this.onCameraMove,
    this.onRouteCalculated,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late final MapController _mapController;
  final MapboxService _mapboxService = MapboxService();
  final LocationService _locationService = LocationService();

  LatLng _currentPosition = const LatLng(16.7569, -93.1292); // Default Tuxtla Gutiérrez, Chiapas
  LatLng? _destinationLatLng;
  List<LatLng> _routePoints = [];
  StreamSubscription<LatLng>? _locationSubscription;
  
  final List<SimulatedCar> _simulatedCars = [];
  Timer? _simulationTimer;
  final Random _random = Random();
  static const String _mapboxToken = Env.mapboxApiKey;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initDeviceLocation().then((_) {
      _triggerRouteCalculation();
    });
    if (widget.destination != null || widget.destinationLatLng != null) {
      _triggerRouteCalculation();
    }
  }

  void _triggerRouteCalculation() {
    if (widget.destinationLatLng != null) {
      _destinationLatLng = widget.destinationLatLng;
      _fetchRealRoute();
    } else if (widget.destination != null && widget.destination!.isNotEmpty) {
      _geocodeDestination(widget.destination!);
    }
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initDeviceLocation() async {
    final realPosition = await _locationService.getCurrentLocation();
    if (realPosition != null && mounted) {
      setState(() {
        _currentPosition = realPosition;
      });
      _mapController.move(_currentPosition, 15.0);
      _initSimulatedCars();
    }

    _locationSubscription = _locationService.getLocationStream().listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }
    });
  }

  void _initSimulatedCars() {
    _simulatedCars.clear();
    for (int i = 0; i < 5; i++) {
      // Generar autos en un radio de ~1.5 km
      double latOffset = (_random.nextDouble() - 0.5) * 0.02;
      double lngOffset = (_random.nextDouble() - 0.5) * 0.02;
      LatLng startPos = LatLng(_currentPosition.latitude + latOffset, _currentPosition.longitude + lngOffset);
      
      _simulatedCars.add(SimulatedCar(
        position: startPos,
        heading: _random.nextDouble() * 360,
        destination: _generateRandomDestination(startPos),
      ));
    }

    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateSimulatedCars();
    });
  }

  LatLng _generateRandomDestination(LatLng currentPos) {
    double latOffset = (_random.nextDouble() - 0.5) * 0.01;
    double lngOffset = (_random.nextDouble() - 0.5) * 0.01;
    return LatLng(currentPos.latitude + latOffset, currentPos.longitude + lngOffset);
  }

  void _updateSimulatedCars() {
    if (!mounted) return;
    setState(() {
      for (var car in _simulatedCars) {
        // Move towards destination slightly
        double latDiff = car.destination.latitude - car.position.latitude;
        double lngDiff = car.destination.longitude - car.position.longitude;
        
        // If close to destination, get a new one
        if (latDiff.abs() < 0.0001 && lngDiff.abs() < 0.0001) {
          car.destination = _generateRandomDestination(car.position);
          latDiff = car.destination.latitude - car.position.latitude;
          lngDiff = car.destination.longitude - car.position.longitude;
        }

        // Calculate heading
        car.heading = atan2(lngDiff, latDiff) * (180 / pi);

        // Move a fraction of the distance (simulating speed)
        car.position = LatLng(
          car.position.latitude + (latDiff * 0.1),
          car.position.longitude + (lngDiff * 0.1),
        );
      }
    });
  }

  @override
  void didUpdateWidget(MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPinPickerMode && !oldWidget.isPinPickerMode) {
      final centerLoc = widget.originLatLng ?? _currentPosition;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(centerLoc, 16.0);
      });
    }

    if (widget.destination != oldWidget.destination || widget.destinationLatLng != oldWidget.destinationLatLng || widget.originLatLng != oldWidget.originLatLng) {
      if (widget.destinationLatLng != null) {
        _destinationLatLng = widget.destinationLatLng;
        _fetchRealRoute();
      } else if (widget.destination != null && widget.destination!.isNotEmpty) {
        _geocodeDestination(widget.destination!);
      } else {
        setState(() {
          _destinationLatLng = null;
          _routePoints = [];
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_currentPosition, 14.5);
        });
      }
    }
  }

  Future<void> _geocodeDestination(String address) async {
    final startPoint = widget.originLatLng ?? _currentPosition;
    final places = await _mapboxService.searchPlaces(address, proximityLng: startPoint.longitude, proximityLat: startPoint.latitude);
    if (places.isNotEmpty && mounted) {
      final topPlace = places.first;
      final coords = LatLng(topPlace.latitude, topPlace.longitude);
      setState(() {
        _destinationLatLng = coords;
      });
      _fetchRealRoute();
    } else if (mounted) {
      // Fallback si no hay geocodificación
      setState(() {
        _destinationLatLng = LatLng(startPoint.latitude + 0.02, startPoint.longitude + 0.02);
      });
      _fetchRealRoute();
    }
  }

  Future<void> _fetchRealRoute() async {
    if (_destinationLatLng == null) return;

    final startPoint = widget.originLatLng ?? _currentPosition;
    final routeResult = await _mapboxService.getDrivingRoute(startPoint, _destinationLatLng!);

    if (mounted) {
      if (routeResult != null && routeResult.polylinePoints.isNotEmpty) {
        if (widget.onRouteCalculated != null) {
          widget.onRouteCalculated!(routeResult.distanceMeters, routeResult.durationSeconds);
        }
        
        setState(() {
          _routePoints = routeResult.polylinePoints;
        });

        final bounds = LatLngBounds.fromPoints([startPoint, _destinationLatLng!]);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.only(top: 80, bottom: 250, left: 50, right: 50),
            ),
          );
        });
      } else {
        setState(() {
          _routePoints = [startPoint, _destinationLatLng!];
        });
        if (widget.onRouteCalculated != null) {
          widget.onRouteCalculated!(5000, 600); // 5km, 10min fallback
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: 14.5,
            maxZoom: 18.0,
            minZoom: 2.0,
            onPositionChanged: (position, hasGesture) {
              if (widget.onCameraMove != null) {
                widget.onCameraMove!(position.center);
              }
            },
          ),
          children: [
            // Capa de Mapa Mapbox Oscuro
            TileLayer(
              urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
              userAgentPackageName: 'com.taxiseguro.app',
            ),

            // Línea de la ruta real por calles en vehículo (Amarillo vibrante)
            if (!widget.isPinPickerMode && _routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 6.5,
                    color: Colors.black.withValues(alpha: 0.9),
                  ),
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: const Color(0xFFFFD700), // Amarillo brillante
                  ),
                ],
              ),

            // Simulated Cars Layer
            if (_simulatedCars.isNotEmpty)
              MarkerLayer(
                markers: _simulatedCars.map((car) {
                  return Marker(
                    point: car.position,
                    width: 32,
                    height: 32,
                    child: Transform.rotate(
                      angle: car.heading * (pi / 180),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                          border: Border.all(color: Colors.black12, width: 1),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.directions_car,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            // Marcadores
            if (!widget.isPinPickerMode)
              MarkerLayer(
                markers: [
                  // Marcador Origen (Ubicación GPS real o elegida en Amarillo)
                  Marker(
                    point: widget.originLatLng ?? _currentPosition,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Marcador Destino Dinámico
                  if (_destinationLatLng != null)
                    Marker(
                      point: _destinationLatLng!,
                      width: 70,
                      height: 54,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                            child: const Text(
                              'Destino',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),

        // Fijador de Destino/Origen estilo Uber/DiDi (Marcador central flotante)
        if (widget.isPinPickerMode)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 18,
                    color: Colors.black,
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
