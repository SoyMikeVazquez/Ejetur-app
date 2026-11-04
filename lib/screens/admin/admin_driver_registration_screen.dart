import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../env/env.dart';
import '../driver_onboarding_screen.dart';

class AdminDriverRegistrationScreen extends StatefulWidget {
  const AdminDriverRegistrationScreen({super.key});

  @override
  State<AdminDriverRegistrationScreen> createState() => _AdminDriverRegistrationScreenState();
}

class _AdminDriverRegistrationScreenState extends State<AdminDriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleDriverRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      // Crear cliente aislado para no afectar la sesión del admin
      final isolatedClient = SupabaseClient(
        Env.supabaseUrl,
        Env.supabaseAnonKey,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      // 1. Supabase Auth Sign Up en el cliente aislado
      final res = await isolatedClient.auth.signUp(
        email: email,
        password: password,
      );

      final userId = res.user?.id;

      if (userId != null) {
        // 2. Register in public.users
        await isolatedClient.from('users').insert({
          'user_id': userId,
          'nombre': name.isNotEmpty ? name : email.split('@').first,
          'correo': email,
          'telefono': phone,
          'isConductor': true,
        });

        // 3. Register in public.conductores como ACTIVO y APROBADO
        final driverData = {
          'id': userId,
          'user_id': userId,
          'nombre': name.isNotEmpty ? name : 'Conductor Taxiseguro',
          'nombre_completo': name.isNotEmpty ? name : 'Conductor Taxiseguro',
          'correo': email,
          'telefono': phone.isNotEmpty ? phone : '8110002233',
          'estatus': 'activo',
          'Perfi_terminado': true,
          'Aprobacion': 'Aprobado',
        };

        try {
          await isolatedClient.from('conductores').insert(driverData);
        } catch (driverError) {
          debugPrint('Error al insertar en conductores: $driverError');
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => DriverOnboardingScreen(isAdminContext: true, isolatedClient: isolatedClient)),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        String errorMsg = error.message;
        if (errorMsg.contains('User already registered') || errorMsg.contains('already exists')) {
          errorMsg = 'Este correo ya está registrado.';
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Ocurrió un error inesperado al registrar los datos: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool isObscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: isObscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.35)),
            filled: true,
            fillColor: const Color(0xFFF3F3F3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alta Directa de Conductor',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Registra un nuevo conductor. Se dará de alta directamente como ACTIVO.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  _buildTextField(
                    controller: _nameController,
                    label: 'Nombre completo',
                    hint: 'Ej: Juan Pérez',
                    validator: (value) => value == null || value.isEmpty ? 'Por favor ingresa un nombre' : null,
                  ),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    hint: 'ejemplo@taxiseguro.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Por favor ingresa un correo';
                      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegExp.hasMatch(value.trim())) return 'Ingresa un correo electrónico válido';
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: _phoneController,
                    label: 'Número de teléfono',
                    hint: 'Ej: 8110002233',
                    keyboardType: TextInputType.phone,
                    validator: (value) => value == null || value.isEmpty ? 'Por favor ingresa un teléfono' : null,
                  ),

                  _buildTextField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    hint: '••••••••',
                    isObscure: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Por favor ingresa una contraseña';
                      if (value.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleDriverRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF050505), // Modern Black
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Dar de Alta',
                              style: TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
