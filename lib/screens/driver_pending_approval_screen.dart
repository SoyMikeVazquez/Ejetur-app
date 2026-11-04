import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'auth_screen.dart';
import 'driver_main_screen.dart';
import 'driver_onboarding_screen.dart';

class DriverPendingApprovalScreen extends StatefulWidget {
  final String status; // 'Pendiente', 'No aprobado', etc.

  const DriverPendingApprovalScreen({
    super.key,
    this.status = 'Pendiente',
  });

  @override
  State<DriverPendingApprovalScreen> createState() => _DriverPendingApprovalScreenState();
}

class _DriverPendingApprovalScreenState extends State<DriverPendingApprovalScreen> {
  bool _isChecking = false;
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  Future<void> _checkApprovalStatus() async {
    setState(() => _isChecking = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final conductorRes = await Supabase.instance.client
          .from('conductores')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (conductorRes != null) {
        final rawAprobacion = conductorRes['Aprobación'] ??
            conductorRes['Aprobacion'] ??
            conductorRes['aprobacion'] ??
            conductorRes['aprobación'] ??
            'Pendiente';

        final String statusStr = rawAprobacion.toString();

        if (statusStr.toLowerCase() == 'aprobado') {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DriverMainScreen()),
            );
            return;
          }
        }

        setState(() {
          _currentStatus = statusStr;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                statusStr.toLowerCase() == 'aprobado'
                    ? '¡Tu cuenta ha sido aprobada!'
                    : 'Estado actual: $statusStr',
              ),
              backgroundColor: statusStr.toLowerCase() == 'aprobado' ? Colors.green : Colors.black87,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar estado: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRejected = _currentStatus.toLowerCase() == 'no aprobado';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
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
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Icon Container
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: isRejected ? Colors.red.shade50 : Colors.black.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: isRejected ? Colors.redAccent : const Color(0xFF050505),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isRejected ? Colors.redAccent.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                      size: 40,
                      color: isRejected ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 32),

              // Title
              Text(
                isRejected ? 'Solicitud No Aprobada' : 'Perfil en Revisión',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Colors.black,
                ),
              ).animate().fade(duration: 500.ms, delay: 150.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isRejected ? Colors.red.shade100 : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isRejected ? Colors.red : Colors.amber.shade800,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRejected ? 'Estado: No aprobado' : 'Estado: Pendiente de Aprobación',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isRejected ? Colors.red.shade900 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 500.ms, delay: 250.ms),

              const SizedBox(height: 20),

              // Description
              Text(
                isRejected
                    ? 'Tu solicitud no ha sido aprobada por nuestro equipo de administración. Por favor comunícate con soporte o actualiza tus documentos.'
                    : '¡Excelente! Has completado tu perfil y subido tus documentos oficiales. Nuestro equipo de Taxiseguro los validará manualmente.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ).animate().fade(duration: 500.ms, delay: 350.ms),

              const SizedBox(height: 24),

              // Steps completed card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildCheckRow(Icons.directions_car, 'Datos del Vehículo', true),
                    const SizedBox(height: 12),
                    _buildCheckRow(Icons.description, 'Documentos (INE, Licencia, Seguro)', true),
                    const SizedBox(height: 12),
                    _buildCheckRow(Icons.account_balance, 'Datos Bancarios', true),
                  ],
                ),
              ).animate().fade(duration: 500.ms, delay: 450.ms).slideY(begin: 0.1, end: 0),

              const Spacer(),

              // Check Status Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _checkApprovalStatus,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Icon(Icons.refresh_rounded, color: Colors.black),
                  label: Text(
                    _isChecking ? 'Verificando...' : 'Comprobar Estado',
                    style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF050505), // Modern Black
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ).animate().fade(duration: 500.ms, delay: 550.ms),

              if (isRejected) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const DriverOnboardingScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Reenviar Documentos',
                      style: TextStyle(
                        fontFamily: 'Google Sans',
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckRow(IconData icon, String title, bool isDone) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
        Icon(
          isDone ? Icons.check_circle : Icons.circle_outlined,
          color: isDone ? Colors.green : Colors.grey,
          size: 20,
        ),
      ],
    );
  }
}
