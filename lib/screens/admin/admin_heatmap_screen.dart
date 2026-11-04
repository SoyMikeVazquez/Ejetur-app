import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/admin_service.dart';
import '../../env/env.dart';
class AdminHeatmapScreen extends StatefulWidget {
  const AdminHeatmapScreen({super.key});

  @override
  State<AdminHeatmapScreen> createState() => _AdminHeatmapScreenState();
}

class _AdminHeatmapScreenState extends State<AdminHeatmapScreen> {
  final AdminService _adminService = AdminService();
  final MapController _mapController = MapController();

  bool _isLoading = true;
  bool _isAddingZone = false;
  bool _isUpdatingRates = false;
  List<LatLng> _heatPoints = [];
  List<Map<String, dynamic>> _pricingZones = [];
  List<Map<String, dynamic>> _densityRates = [];
  final Map<int, TextEditingController> _rateControllers = {};

  static const String _mapboxToken = Env.mapboxApiKey;

  @override
  void initState() {
    super.initState();
    _loadHeatmap();
  }

  @override
  void dispose() {
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHeatmap() async {
    setState(() => _isLoading = true);
    final points = await _adminService.getHeatmapPoints();
    final zones = await _adminService.getDynamicPricingZones();
    final rates = await _adminService.getDensityPricing();
    if (mounted) {
      for (final rate in rates) {
        final id = rate['id'] as int?;
        if (id != null) {
          final val = rate['Porcentaje']?.toString() ?? '0';
          if (_rateControllers.containsKey(id)) {
            _rateControllers[id]!.text = val;
          } else {
            _rateControllers[id] = TextEditingController(text: val);
          }
        }
      }
      setState(() {
        _heatPoints = points;
        _pricingZones = zones;
        _densityRates = rates;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDensityRates() async {
    setState(() => _isUpdatingRates = true);
    try {
      for (final rate in _densityRates) {
        final id = rate['id'] as int?;
        if (id != null && _rateControllers.containsKey(id)) {
          final numVal = num.tryParse(_rateControllers[id]!.text.trim()) ?? 0;
          await _adminService.updateDensityPricing(id, numVal);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Porcentajes de densidad actualizados correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        await _loadHeatmap();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingRates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Mapas de Calor (Demanda)',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHeatmap,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF050505)))
          : Stack(
              children: [
                // Mapa Mapbox Oscuro
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _heatPoints.isNotEmpty ? _heatPoints.first : const LatLng(16.7370, -92.6376),
                    initialZoom: 12.5,
                    onTap: (tapPosition, latLng) {
                      if (_isAddingZone) {
                        _showAddZoneDialog(latLng);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxToken',
                      userAgentPackageName: 'com.taxiseguro.app',
                    ),
                    // Capas de círculos de calor (Heatmap Clusters)
                    CircleLayer(
                      circles: _heatPoints.map((point) {
                        return CircleMarker(
                          point: point,
                          radius: 45,
                          useRadiusInMeter: false,
                          color: Colors.redAccent.withValues(alpha: 0.35),
                          borderColor: Colors.amber.withValues(alpha: 0.6),
                          borderStrokeWidth: 2,
                        );
                      }).toList(),
                    ),
                    CircleLayer(
                      circles: _heatPoints.map((point) {
                        return CircleMarker(
                          point: point,
                          radius: 22,
                          useRadiusInMeter: false,
                          color: const Color(0xFFFFD700).withValues(alpha: 0.65),
                          borderColor: const Color(0xFF050505),
                          borderStrokeWidth: 1.5,
                        );
                      }).toList(),
                    ),
                    MarkerLayer(
                      markers: _heatPoints.map((point) {
                        return Marker(
                          point: point,
                          width: 14,
                          height: 14,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF050505),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.white, blurRadius: 4),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    CircleLayer(
                      circles: _pricingZones.where((z) => z['is_active'] == true).map((zone) {
                        return CircleMarker(
                          point: LatLng((zone['lat'] as num).toDouble(), (zone['lng'] as num).toDouble()),
                          radius: (zone['radius_km'] as num).toDouble() * 1000,
                          useRadiusInMeter: true,
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderColor: Colors.blueAccent,
                          borderStrokeWidth: 2,
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Leyenda de Demanda
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Densidad de Solicitudes en Tiempo Real',
                          style: TextStyle(color: Colors.white, fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem('Muy alta', Colors.redAccent),
                            const SizedBox(width: 8),
                            _buildLegendItem('Moderada', const Color(0xFFFFD700)),
                            const SizedBox(width: 8),
                            _buildLegendItem('Baja', const Color(0xFF050505)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: _isUpdatingRates ? null : _saveDensityRates,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF050505),
                              disabledBackgroundColor: const Color(0xFF050505).withValues(alpha: 0.6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: _isUpdatingRates
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync, color: Colors.black, size: 20),
                            label: Text(
                              _isUpdatingRates ? 'Actualizando...' : 'Actualizar',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                fontFamily: 'Google Sans',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms).slideY(begin: 0.2, end: 0),
                ),
                
                // Botón de Tarifa Dinámica reubicado en la parte superior derecha
                Positioned(
                  top: 16,
                  right: 16,
                  child: _isAddingZone
                      ? FloatingActionButton.extended(
                          backgroundColor: Colors.redAccent,
                          onPressed: () => setState(() => _isAddingZone = false),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text('Cancelar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      : FloatingActionButton.extended(
                          backgroundColor: const Color(0xFF050505),
                          onPressed: _showPricingZonesSheet,
                          icon: const Icon(Icons.monetization_on, color: Colors.black),
                          label: const Text('Lugares con mayor tarifa', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem(String densityLabel, Color color) {
    final rate = _densityRates.firstWhere(
      (r) => r['Densidad'].toString().toLowerCase() == densityLabel.toLowerCase(),
      orElse: () => {},
    );
    final id = rate.isNotEmpty ? rate['id'] as int? : null;
    final controller = id != null ? _rateControllers[id] : null;

    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  densityLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (controller != null)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  suffixText: '%',
                  suffixStyle: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPricingZonesSheet() {
    // Aquí podemos abrir un modal para añadir/editar/eliminar zonas.
    // Por brevedad de este paso, le recordaremos al usuario cómo administrarlo.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Zonas de Tarifa Dinámica', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF050505), size: 28),
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _isAddingZone = true);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Toca en el mapa para establecer el centro de la zona')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_pricingZones.isEmpty)
                const Text('No hay zonas configuradas.', style: TextStyle(color: Colors.grey))
              else
                ..._pricingZones.map((z) => ListTile(
                  title: Text(z['name'] ?? 'Zona', style: const TextStyle(color: Colors.white)),
                  subtitle: Text('${z['radius_km']} km | +${z['percentage_increase']}%', style: const TextStyle(color: Colors.grey)),
                  trailing: Switch(
                    value: z['is_active'] == true,
                    activeColor: const Color(0xFF050505),
                    onChanged: (val) async {
                      await _adminService.toggleDynamicPricingZone(z['id'], val);
                      _loadHeatmap();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                )),
            ],
          ),
        );
      }
    );
  }

  void _showAddZoneDialog(LatLng latLng) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController radiusController = TextEditingController(text: '2.0');
    final TextEditingController percentageController = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Nueva Zona Dinámica', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre de la zona', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: radiusController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Radio (km)', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: percentageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Aumento de tarifa (%)', labelStyle: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF050505)),
              onPressed: () async {
                final name = nameController.text.trim();
                final radius = double.tryParse(radiusController.text) ?? 2.0;
                final percentage = double.tryParse(percentageController.text) ?? 20.0;
                
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor ingresa un nombre para la zona')),
                  );
                  return;
                }

                final errorMsg = await _adminService.addDynamicPricingZone(
                  name: name,
                  lat: latLng.latitude,
                  lng: latLng.longitude,
                  radiusKm: radius,
                  percentageIncrease: percentage,
                );

                if (errorMsg == null) {
                  _loadHeatmap();
                  setState(() => _isAddingZone = false);
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Zona añadida correctamente')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Error Detallado', style: TextStyle(color: Colors.white)),
                        content: Text(errorMsg, style: const TextStyle(color: Colors.redAccent)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Entendido', style: TextStyle(color: Colors.grey)),
                          )
                        ],
                      )
                    );
                  }
                }
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }


}
