import 'package:flutter/material.dart';
import 'driver_map_screen.dart';
import 'driver_finances_screen.dart';
import 'driver_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import '../services/trip_service.dart';
import '../services/driver_shift_service.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

class DriverMainScreen extends StatefulWidget {
  const DriverMainScreen({super.key});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DriverMapScreen(),
    DriverFinancesScreen(),
    DriverProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final double screen = MediaQuery.sizeOf(context).width;
    final double barWidth = (screen - 36).clamp(280.0, 520.0);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          LiquidGlassTabBar(
            items: [
              _buildTabItem(Icons.directions_car_filled, 'Mapa'),
              _buildTabItem(Icons.account_balance_wallet, 'Finanzas'),
              _buildTabItem(Icons.settings, 'Ajustes'),
              _buildTabItem(Icons.logout, 'Salir'),
            ],
            selectedIndex: _currentIndex,
            onChanged: (index) {
              if (index == 3) {
                _handleLogout();
                return;
              }
              setState(() => _currentIndex = index);
            },
            width: barWidth,
            height: 64,
            itemPadding: 4,
            margin: const EdgeInsets.only(bottom: 24),
            style: const LiquidGlassStyle(
              shape: LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: 32,
                clipQuality: LiquidGlassClipQuality.exact,
              ),
              specular: LiquidGlassLight.specular(
                thickness: 6.5,
                angle: 45,
              ),
              glow: LiquidGlassLight.glow(
                thickness: 16.0,
                angle: 135,
              ),
              refractionIndex: 1.35,
              refractionWidth: 24,
              dispersion: 3.0,
              color: Color(0x35FFFFFF), // Cristal translúcido óptico
              blur: 14,
              shadow: LiquidGlassShadow(blur: 16, opacity: 0.20, offset: Offset(0, 6)),
            ),
            itemStyle: const LiquidGlassTabItemStyle(
              selectedColor: Colors.black,
              unselectedColor: Colors.black,
              iconSize: 23,
              labelFontSize: 11,
              iconLabelGap: 2,
              underGlassIconSize: 26,
              underGlassLabelFontSize: 11,
              selectedFontWeight: FontWeight.w900,
              unselectedFontWeight: FontWeight.w800,
            ),
            pillStyle: const LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.both,
              growHeight: 6.0,
              refractionIndex: 1.30,
              refractionWidth: 18,
              rest: LiquidGlassStyle(
                shape: LiquidGlassShape.continuousRoundedRectangle(
                  cornerRadius: 26,
                  clipQuality: LiquidGlassClipQuality.exact,
                ),
                color: Color(0x22000000), // Cristal ahumado translúcido de contraste
              ),
            ),
          ),
        ],
      ),
    );
  }

  LiquidGlassTabBarItem _buildTabItem(IconData icon, String label) {
    final bool isLogout = icon == Icons.logout;
    return LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, i) {
        return Icon(
          icon,
          size: i.underGlass == true ? 25 : 23,
          color: isLogout ? Colors.redAccent : Colors.black,
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final driverId = Supabase.instance.client.auth.currentUser?.id;
    if (driverId != null) {
      final activeTrip = await TripService().getActiveTrip(driverId);
      if (activeTrip != null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No puedes cerrar sesión mientras tienes un viaje activo en curso.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      try {
        await Supabase.instance.client.from('conductores').update({
          'isActivo': false,
          'estatus': 'inactivo',
        }).eq('user_id', driverId);
        await DriverShiftService().recordDisconnection(driverId);
      } catch (_) {}
    }
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }
}
