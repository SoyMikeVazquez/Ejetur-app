import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip.dart';
import '../services/trip_service.dart';
import 'trip_detail_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  final bool showBackButton;
  const TripHistoryScreen({super.key, this.showBackButton = false});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  final TripService _tripService = TripService();
  late Future<List<Trip>> _tripsFuture;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  void _loadTrips() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        _tripsFuture = _tripService.getUserTrips(user.id);
      });
    } else {
      setState(() {
        _tripsFuture = Future.value([]);
      });
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'Fecha desconocida';
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _getMonthName(local.month);
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day de $month • $hour:$minute $period';
  }

  String _getMonthName(int month) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          'Mis Viajes',
          style: TextStyle(
            fontFamily: 'Google Sans',
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: () async {
          _loadTrips();
        },
        child: FutureBuilder<List<Trip>>(
          future: _tripsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.black),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                    const SizedBox(height: 12),
                    const Text('Error al cargar el historial de viajes'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadTrips,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final trips = snapshot.data ?? [];

            if (trips.isEmpty) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F3F3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_outlined, size: 64, color: Colors.black),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Aún no tienes viajes registrados',
                        style: TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tus viajes realizados y confirmados aparecerán aquí.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF050505), // Modern Black
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Pedir un viaje ahora', style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _buildTripCard(trip);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTripCard(Trip trip) {
    Color statusColor;
    String statusText;

    switch (trip.status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completado';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelado';
        break;
      case 'in_progress':
      default:
        statusColor = Colors.blue;
        statusText = 'En proceso';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailScreen(trip: trip),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Date & Status Chip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(trip.createdAt),
                    style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Timeline: Origin to Destination
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Visual Timeline Indicator
                  Column(
                    children: [
                      const Icon(Icons.circle, size: 12, color: Colors.black),
                      Container(
                        width: 2,
                        height: 28,
                        color: Colors.grey[300],
                      ),
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF050505)),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Address Text Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Origin Address
                        Text(
                          trip.originAddress,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),

                        // Destination Address
                        Text(
                          trip.destinationAddress,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: Color(0xFFEEEEEE)),
              ),

              // Bottom Row: Price & Ver Detalle button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Costo del viaje',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '\$${(trip.fare ?? 120.00).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Text(
                          'Detalles',
                          style: TextStyle(
                            fontFamily: 'Google Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16, color: Colors.black),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
