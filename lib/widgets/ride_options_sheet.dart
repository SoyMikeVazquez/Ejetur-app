import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/pricing_service.dart';

class RideOptionsSheet extends StatelessWidget {
  final String origin;
  final LatLng? originLatLng;
  final String destination;
  final double? distanceMeters;
  final double? durationSeconds;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback? onEditOrigin;
  final VoidCallback? onEditDestination;

  const RideOptionsSheet({
    super.key,
    required this.origin,
    this.originLatLng,
    required this.destination,
    this.distanceMeters,
    this.durationSeconds,
    required this.onCancel,
    required this.onConfirm,
    this.onEditOrigin,
    this.onEditDestination,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular tarifa en tiempo real (o fallback a $120.00 si Mapbox aún no responde)
    String displayedPrice = '\$120.00';
    if (distanceMeters != null && durationSeconds != null) {
      final double price = PricingService.calculateDynamicPrice(distanceMeters!, durationSeconds!, origin: originLatLng);
      displayedPrice = '\$${price.toStringAsFixed(2)}';
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // 1. Origin & Destination Text Fields Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // Origin Box
                  GestureDetector(
                    onTap: onEditOrigin ?? onEditDestination ?? onCancel,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!, width: 1.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location, color: Colors.black, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              origin,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.black87),
                            onPressed: onEditOrigin ?? onEditDestination ?? onCancel,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Destination Box
                  GestureDetector(
                    onTap: onEditDestination ?? onCancel,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              destination,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.black87),
                            onPressed: onEditDestination ?? onCancel,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ride Options (Solo Taxiseguro Estándar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildRideOption(
                context,
                title: 'Taxiseguro Estándar',
                subtitle: durationSeconds != null 
                    ? 'Viaje en ~${(durationSeconds! / 60).ceil()} min' 
                    : 'Calculando tiempo...',
                price: displayedPrice,
                icon: Icons.local_taxi,
                isSelected: true,
              ),
            ),

            const SizedBox(height: 8),

            // Payment method and Confirm Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.money, size: 20, color: Colors.green),
                      const SizedBox(width: 12),
                      const Text(
                        'Efectivo',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Back/Cancel button
                      Material(
                        color: Colors.grey[200],
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: onCancel,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Confirm button (30px radius)
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF050505), // Modern Black
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Confirmar Taxiseguro',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
      ),
    );
  }

  Widget _buildRideOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required bool isSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF3F3F3) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected ? Colors.black : Colors.transparent,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 40, color: Colors.black87),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              fontFamily: 'Google Sans',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
