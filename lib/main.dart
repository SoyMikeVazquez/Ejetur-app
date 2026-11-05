import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env/env.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_router_screen.dart';
import 'screens/update_password_screen.dart';
import 'theme/app_theme.dart';
import 'services/background_service.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await initializeBackgroundService();
    } catch (e) {
      debugPrint('Error initializing background service: $e');
    }
  }
  
  // Initialize date formatting for Spanish locales
  try {
    await initializeDateFormatting('es_MX', null);
  } catch (e) {
    debugPrint('Error initializing date formatting: $e');
  }
  
  try {
    // Initialize Supabase using database credentials
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
  }

  runApp(const TaxiSeguroApp());
}

class TaxiSeguroApp extends StatelessWidget {
  const TaxiSeguroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taxiseguro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Puedes cambiar a ThemeMode.system si deseas
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        initialData: AuthState(AuthChangeEvent.initialSession, Supabase.instance.client.auth.currentSession),
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Colors.black),
              ),
            );
          }

          final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
          final event = snapshot.data?.event;

          if (event == AuthChangeEvent.passwordRecovery) {
            return const UpdatePasswordScreen();
          }

          if (session != null) {
            return const SplashRouterScreen();
          } else {
            return const AuthScreen();
          }
        },
      ),
    );
  }
}
