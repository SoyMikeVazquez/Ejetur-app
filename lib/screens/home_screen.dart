import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/map_widget.dart';
import '../widgets/search_bottom_sheet.dart';
import '../widgets/ride_options_sheet.dart';
import '../widgets/pin_picker_sheet.dart';
import '../widgets/searching_driver_sheet.dart';
import '../widgets/active_trip_sheet.dart';
import '../screens/trip_history_screen.dart';
import '../screens/profile_screen.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';
import '../services/mapbox_service.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TripService _tripService = TripService();
  final MapboxService _mapboxService = MapboxService();
  
  // Destination and Route State
  String? _selectedOrigin;
  LatLng? _selectedOriginLatLng;
  String? _selectedDestination;
  LatLng? _selectedDestinationLatLng;
  double? _routeDistance;
  double? _routeDuration;
  bool _isSearching = false;
  bool _isLoading = false;
  bool _isSearchingDriver = false;
  bool _isDriverAssigned = false;

  // Pin Picker State (Uber / DiDi pin selection mode)
  bool _isPinPickerMode = false;
  bool _isPinPickerForOrigin = false;
  String _pinnedAddress = '';
  Timer? _geocodeDebounceTimer;

  @override
  void dispose() {
    _geocodeDebounceTimer?.cancel();
    super.dispose();
  }

  LatLng? _lastPinCenter;

  void _onCameraMove(LatLng center) {
    if (!_isPinPickerMode) return;
    _lastPinCenter = center;

    _geocodeDebounceTimer?.cancel();
    _geocodeDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final address = await _mapboxService.reverseGeocode(center);
      if (mounted && address != null) {
        setState(() {
          _pinnedAddress = address;
        });
      }
    });
  }

  void _onRouteSelected(String origin, LatLng? originLatLng, String destination, LatLng? destinationLatLng) {
    setState(() {
      _selectedOrigin = origin;
      _selectedOriginLatLng = originLatLng;
      _selectedDestination = destination;
      if (destinationLatLng != null) {
        _selectedDestinationLatLng = destinationLatLng;
      }
      _isSearching = false;
    });
  }

  void _onPinConfirmed() {
    final chosenAddress = _pinnedAddress.isNotEmpty ? _pinnedAddress : 'Ubicación seleccionada en mapa';
    setState(() {
      _isPinPickerMode = false;
      if (_isPinPickerForOrigin) {
        _selectedOrigin = chosenAddress;
        _selectedOriginLatLng = _lastPinCenter;
        _onRouteSelected(chosenAddress, _lastPinCenter, _selectedDestination ?? '', _selectedDestinationLatLng);
      } else {
        _selectedDestinationLatLng = _lastPinCenter;
        _onRouteSelected(_selectedOrigin ?? 'Ubicación actual', _selectedOriginLatLng, chosenAddress, _lastPinCenter);
      }
    });
  }

  void _onCancelRide() {
    setState(() {
      _selectedOrigin = null;
      _selectedOriginLatLng = null;
      _selectedDestination = null;
      _selectedDestinationLatLng = null;
      _routeDistance = null;
      _routeDuration = null;
      _isPinPickerMode = false;
      _isSearchingDriver = false;
      _isDriverAssigned = false;
    });
  }

  Future<void> _onConfirmRide() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _selectedOrigin == null || _selectedDestination == null) return;

    setState(() {
      _isLoading = true;
    });

    final locService = LocationService();
    final currentLoc = await locService.getCurrentLocation();
    final double originLat = _selectedOriginLatLng?.latitude ?? currentLoc?.latitude ?? GeofenceService.defaultChiapasCenter.latitude;
    final double originLng = _selectedOriginLatLng?.longitude ?? currentLoc?.longitude ?? GeofenceService.defaultChiapasCenter.longitude;

    // Validación de zona: Solo permitido en Chiapas
    final bool canRequest = await GeofenceService.canRequestTrip(
      userId: user.id,
      origin: LatLng(originLat, originLng),
    );

    if (!canRequest) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text('Zona no disponible'),
              ],
            ),
            content: const Text(
              'Por el momento, el servicio de TaxiSeguro solo está disponible para solicitar conductores dentro del estado de Chiapas.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ],
          ),
        );
      }
      return;
    }

    final newTrip = Trip(
      userId: user.id,
      originAddress: _selectedOrigin!,
      destinationAddress: _selectedDestination!,
      originLat: originLat,
      originLng: originLng,
      destinationLat: _selectedDestinationLatLng?.latitude,
      destinationLng: _selectedDestinationLatLng?.longitude,
    );

    final trip = await _tripService.createTrip(newTrip);

    setState(() {
      _isLoading = false;
    });

    if (trip != null) {
      setState(() {
        _isSearchingDriver = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Viaje confirmado! Buscando conductor...'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear el viaje. Intenta de nuevo.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const Drawer(
        child: UserDrawerContent(),
      ),
      body: Stack(
        children: [
          // 1. Map Background (Con soporte para fijador de mapa)
          Positioned.fill(
            child: MapWidget(
              destination: _selectedDestination,
              destinationLatLng: _selectedDestinationLatLng,
              isPinPickerMode: _isPinPickerMode,
              onCameraMove: _onCameraMove,
              onRouteCalculated: (distance, duration) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _routeDistance = distance;
                      _routeDuration = duration;
                    });
                  }
                });
              },
            ),
          ),
          
          // 2. Floating Menu Button OR Back Button when in Pin Picker Mode
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () {
                if (_isPinPickerMode) {
                  setState(() {
                    _isPinPickerMode = false;
                  });
                } else {
                  _scaffoldKey.currentState?.openDrawer();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  _isPinPickerMode ? Icons.arrow_back : Icons.menu,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
          ),

          // 3. Floating Quick Info / Weather Card (Top Right)
          if (!_isPinPickerMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.security_outlined,
                      color: Colors.green,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Seguro',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Dynamic Bottom Sheets based on current mode
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _isLoading
                ? const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : _isDriverAssigned
                    ? ActiveTripSheet(
                        origin: _selectedOrigin ?? 'Ubicación actual',
                        destination: _selectedDestination!,
                        onFinishTrip: _onCancelRide,
                      )
                    : _isSearchingDriver
                        ? SearchingDriverSheet(
                            origin: _selectedOrigin ?? 'Ubicación actual',
                            destination: _selectedDestination!,
                            onCancel: _onCancelRide,
                          )
                    : _isPinPickerMode
                        ? PinPickerSheet(
                            isOrigin: _isPinPickerForOrigin,
                            currentAddress: _pinnedAddress,
                            onConfirm: _onPinConfirmed,
                          )
                    : _selectedDestination == null
                        ? SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: SearchBottomSheet(
                              onRouteSelected: _onRouteSelected,
                              onOpenPinPicker: (isOrigin) {
                                setState(() {
                                  _isPinPickerMode = true;
                                  _isPinPickerForOrigin = isOrigin;
                                });
                              },
                              isSearching: _isSearching,
                              onSearchStateChanged: (searching) {
                                setState(() {
                                  _isSearching = searching;
                                });
                              },
                            ),
                          )
                        : SizedBox(
                            height: MediaQuery.of(context).size.height * 0.65,
                            child: RideOptionsSheet(
                              origin: _selectedOrigin ?? 'Ubicación actual',
                              originLatLng: _selectedOriginLatLng,
                              destination: _selectedDestination!,
                              distanceMeters: _routeDistance,
                              durationSeconds: _routeDuration,
                              onCancel: _onCancelRide,
                              onConfirm: _onConfirmRide,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class UserDrawerContent extends StatelessWidget {
  const UserDrawerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final String email = user?.email ?? 'usuario@taxiseguro.com';
    final String displayName = email.split('@')[0];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          child: UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
            ),
            margin: EdgeInsets.zero,
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.black),
            ),
            accountName: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              email,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildDrawerItem(
          icon: Icons.history,
          title: 'Mis Viajes',
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TripHistoryScreen(),
              ),
            );
          },
        ),
        _buildDrawerItem(
          icon: Icons.payment,
          title: 'Pago',
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        _buildDrawerItem(icon: Icons.card_giftcard, title: 'Promociones', onTap: () {}),
        _buildDrawerItem(icon: Icons.help_outline, title: 'Ayuda', onTap: () {}),
        const Divider(height: 32, thickness: 1, color: Colors.black12),
        _buildDrawerItem(
          icon: Icons.person_outline,
          title: 'Mi Perfil',
          onTap: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        _buildDrawerItem(
          icon: Icons.logout,
          title: 'Cerrar sesión',
          textColor: Colors.redAccent,
          iconColor: Colors.redAccent,
          onTap: () async {
            Navigator.of(context).pop();
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = Colors.black87,
    Color iconColor = Colors.black87,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 26),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      onTap: onTap,
    );
  }
}
