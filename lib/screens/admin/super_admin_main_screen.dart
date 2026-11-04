import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/admin_service.dart';
import '../auth_screen.dart';
import 'admin_drivers_monitor_screen.dart';
import 'admin_users_screen.dart';
import 'admin_finances_screen.dart';
import 'admin_heatmap_screen.dart';
import 'admin_approvals_screen.dart';
import 'admin_trips_history_screen.dart';
import 'admin_cutoff_dates_screen.dart';
import 'admin_ads_screen.dart';
import '../../widgets/admin/dashboard_revenue_card.dart';

class SuperAdminMainScreen extends StatefulWidget {
  const SuperAdminMainScreen({super.key});

  @override
  State<SuperAdminMainScreen> createState() => _SuperAdminMainScreenState();
}

class _SuperAdminMainScreenState extends State<SuperAdminMainScreen> {
  final AdminService _adminService = AdminService();
  final GlobalKey<DashboardRevenueCardState> _revenueCardKey = GlobalKey<DashboardRevenueCardState>();
  bool _isLoading = true;
  AdminStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _adminService.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
      _revenueCardKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final adminEmail = user?.email ?? 'admin@taxiseguro.mx';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadStats();
                  await _revenueCardKey.currentState?.reload();
                },
                color: Colors.black,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    // Header con insignia de Super Admin
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.shield, color: Color(0xFF050505), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'SUPER ADMIN',
                                    style: TextStyle(
                                      color: Color(0xFF050505),
                                      fontFamily: 'Google Sans',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Dashboard General',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              adminEmail,
                              style: const TextStyle(fontFamily: 'Inter', color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 24),
                            padding: const EdgeInsets.all(14),
                            tooltip: 'Cerrar sesión',
                            onPressed: () async {
                              await Supabase.instance.client.auth.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 400.ms).slideY(begin: -0.1, end: 0),

                    const SizedBox(height: 24),

                    // Banner de Alerta de Aprobaciones Pendientes si las hay
                    if ((_stats?.pendingApprovals ?? 0) > 0)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()),
                          ).then((_) => _loadStats());
                        },
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.priority_high_rounded, color: Colors.amber, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_stats!.pendingApprovals} Conductores Pendientes',
                                      style: const TextStyle(
                                        fontFamily: 'Google Sans',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const Text(
                                      'Toca aquí para revisar expedientes y aprobar.',
                                      style: TextStyle(fontFamily: 'Inter', color: Colors.black87, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                            ],
                          ),
                        ),
                      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                    // Resumen Métricas Rápidas
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Conductores',
                            '${_stats?.activeDrivers ?? 0} / ${_stats?.totalDrivers ?? 0}',
                            'Activos / Total',
                            Icons.local_taxi,
                            const Color(0xFF050505),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Usuarios',
                            '${_stats?.totalUsers ?? 0}',
                            'Registrados',
                            Icons.people_alt,
                            const Color(0xFF050505),
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Viajes Totales',
                            '${_stats?.totalTrips ?? 0}',
                            'Completados',
                            Icons.navigation,
                            const Color(0xFF050505),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTripsHistoryScreen())),
                            showActionIcon: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Próximo Corte',
                            _stats?.nextCutoffDate != null ? '${_stats!.nextCutoffDate!.day.toString().padLeft(2, '0')}/${_stats!.nextCutoffDate!.month.toString().padLeft(2, '0')}' : 'N/A',
                            'Fecha programada',
                            Icons.event_available,
                            const Color(0xFF050505),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCutoffDatesScreen())),
                            showActionIcon: true,
                          ),
                        ),
                      ],
                    ).animate().fade(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 20),

                    // Gráfica de Ingresos, Métodos de Pago y Acceso a Finanzas Generales
                    DashboardRevenueCard(
                      key: _revenueCardKey,
                      adminService: _adminService,
                    ).animate().fade(duration: 400.ms, delay: 180.ms).slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 28),

                    // Menú General de Opciones
                    const Text(
                      'Panel de Control',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. Monitor de Conductores
                    _buildModuleTile(
                      title: '1. Monitor de Conductores',
                      subtitle: 'Ubicación en mapa en vivo, finanzas, viajes, reseñas y cancelaciones',
                      icon: Icons.map_outlined,
                      badge: '${_stats?.totalDrivers ?? 0} conductores',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDriversMonitorScreen())),
                    ),

                    // 2. Visualizador de Clientes y Usuarios
                    _buildModuleTile(
                      title: '2. Visualizador de Clientes y Usuarios',
                      subtitle: 'Directorio completo, historial de viajes y búsqueda por correo/teléfono',
                      icon: Icons.people_outline,
                      badge: '${_stats?.totalUsers ?? 0} usuarios',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
                    ),

                    // 3. Visualizador en Gráfica de Finanzas
                    _buildModuleTile(
                      title: '3. Visualizador en Gráfica de Finanzas',
                      subtitle: 'Gráficas de facturación, comisiones retenidas del 20% y balances',
                      icon: Icons.bar_chart_rounded,
                      badge: 'Finanzas',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinancesScreen())),
                    ),

                    // 4. Mapas de Calor Actuales
                    _buildModuleTile(
                      title: '4. Mapas de Calor Actuales',
                      subtitle: 'Concentración y densidad de demanda de viajes en tiempo real',
                      icon: Icons.local_fire_department,
                      badge: 'En vivo',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHeatmapScreen())),
                    ),

                    // 5. Monitor de Aprobación de Conductores
                    _buildModuleTile(
                      title: '5. Monitor de Aprobación de Conductores',
                      subtitle: 'Aprobar o rechazar solicitudes con visor de INE, Licencia, Seguro y Circulación',
                      icon: Icons.assignment_turned_in_outlined,
                      badge: '${_stats?.pendingApprovals ?? 0} pendientes',
                      isHighlight: (_stats?.pendingApprovals ?? 0) > 0,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen())).then((_) => _loadStats()),
                    ),

                    // 6. Historial de Viajes Global
                    _buildModuleTile(
                      title: '6. Historial y Monitoreo de Viajes',
                      subtitle: 'Listado global de todos los viajes registrados por día con buscador',
                      icon: Icons.history_edu,
                      badge: 'Historial Global',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTripsHistoryScreen())),
                    ),

                    // 7. Fechas de Corte
                    _buildModuleTile(
                      title: '7. Fechas de Corte (Pagos de Conductores)',
                      subtitle: 'Listado de fechas de corte y seguimiento de pagos de la plataforma',
                      icon: Icons.calendar_month_outlined,
                      badge: 'Pagos',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCutoffDatesScreen())),
                    ),

                    // 8. Administrador de Anuncios
                    _buildModuleTile(
                      title: '8. Administrador de Anuncios',
                      subtitle: 'Crear, editar y eliminar los anuncios (Ads) de la plataforma',
                      icon: Icons.campaign_outlined,
                      badge: 'Ads',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAdsScreen())),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String mainValue, String subValue, IconData icon, Color iconColor, {VoidCallback? onTap, bool showActionIcon = false}) {
    final cardContent = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontFamily: 'Inter', color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.black, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainValue,
                    style: const TextStyle(fontFamily: 'Google Sans', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 2),
                  Text(subValue, style: const TextStyle(fontFamily: 'Inter', color: Colors.grey, fontSize: 11)),
                ],
              ),
              if (showActionIcon)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward, size: 16, color: Colors.black87),
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
  }

  Widget _buildModuleTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.amber.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isHighlight ? Border.all(color: Colors.amber.shade200, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHighlight ? Colors.amber : const Color(0xFF050505).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.black, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontFamily: 'Google Sans',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isHighlight ? Colors.amber : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}
