import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'taxiseguro_home_screen.dart';
import 'driver_main_screen.dart';
import 'driver_onboarding_screen.dart';
import 'driver_pending_approval_screen.dart';
import 'driver_face_capture_screen.dart';
import 'admin/super_admin_main_screen.dart';

class SplashRouterScreen extends StatefulWidget {
  const SplashRouterScreen({super.key});

  @override
  State<SplashRouterScreen> createState() => _SplashRouterScreenState();
}

class _SplashRouterScreenState extends State<SplashRouterScreen> {
  @override
  void initState() {
    super.initState();
    _routeUser();
  }

  Future<void> _routeUser() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TaxiseguroHomeScreen()),
          );
        }
        return;
      }

      // 1. Fetch user data from public.users
      Map<String, dynamic>? userRes;
      for (int i = 0; i < 4; i++) {
        userRes = await Supabase.instance.client
            .from('users')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
            
        if (userRes != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      bool isAdmin = false;
      bool isConductor = false;
      bool isProfileComplete = false;
      bool hasProfilePhoto = false;
      String approvalStatus = 'Pendiente';

      if (userRes != null) {
        isAdmin = userRes['isadmin'] == true ||
            userRes['isAdmin'] == true ||
            userRes['is_admin'] == true ||
            userRes['isadmin']?.toString().toLowerCase() == 'true' ||
            userRes['isAdmin']?.toString().toLowerCase() == 'true';

        final bool flagConductor = userRes['isConductor'] == true || userRes['isConductor']?.toString().toLowerCase() == 'true';

        Map<String, dynamic>? conductorRes;
        try {
          conductorRes = await Supabase.instance.client
              .from('conductores')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

          if (conductorRes == null && user.email != null) {
            conductorRes = await Supabase.instance.client
                .from('conductores')
                .select()
                .eq('correo', user.email!)
                .maybeSingle();

            if (conductorRes != null && conductorRes['user_id'] == null) {
              await Supabase.instance.client
                  .from('conductores')
                  .update({'user_id': user.id})
                  .eq('id', conductorRes['id']);
            }
          }
        } catch (e) {
          debugPrint("Error consultando conductores: $e");
        }

        if (flagConductor || conductorRes != null) {
          isConductor = true;
              
          if (conductorRes == null) {
            print("Warning: isConductor is true but no profile in 'conductores' table.");
          } else {
            final isTerminado = conductorRes['Perfi_terminado'] == true ||
                conductorRes['perfi_terminado'] == true ||
                conductorRes['Perfil_terminado'] == true ||
                conductorRes['perfil_terminado'] == true ||
                conductorRes['Perfi_terminado']?.toString().toLowerCase() == 'true' ||
                conductorRes['perfi_terminado']?.toString().toLowerCase() == 'true' ||
                conductorRes['Perfil_terminado']?.toString().toLowerCase() == 'true' ||
                conductorRes['perfil_terminado']?.toString().toLowerCase() == 'true';
            
            final rawAprobacion = conductorRes['Aprobación'] ??
                conductorRes['Aprobacion'] ??
                conductorRes['aprobacion'] ??
                conductorRes['aprobación'] ??
                'Pendiente';
            approvalStatus = rawAprobacion.toString();

            if (isTerminado || approvalStatus.toLowerCase() == 'aprobado' || conductorRes['modelo_auto'] != null) {
              isProfileComplete = true;
            }
            
            final profileImg = conductorRes['imagen_perfil'];
            if (profileImg != null && profileImg.toString().trim().isNotEmpty) {
              hasProfilePhoto = true;
            }

          }
        }
      }

      if (mounted) {
        if (isAdmin) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SuperAdminMainScreen()),
          );
        } else if (isConductor) {
          if (!hasProfilePhoto) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DriverFaceCaptureScreen()),
            );
          } else if (!isProfileComplete) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DriverOnboardingScreen()),
            );
          } else if (approvalStatus.toLowerCase() == 'aprobado') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DriverMainScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => DriverPendingApprovalScreen(status: approvalStatus),
              ),
            );
          }
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TaxiseguroHomeScreen()),
          );
        }
      }
    } catch (e) {
      print('Error routing user: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TaxiseguroHomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}
