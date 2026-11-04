import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'splash_router_screen.dart';
import 'driver_registration_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Custom User fields for Sign Up
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Profile image and Driver Referral fields
  File? _profileImage;
  List<Map<String, dynamic>> _drivers = [];
  final _referralPhoneController = TextEditingController();
  Map<String, dynamic>? _foundReferralDriver;
  bool _isSearchingReferral = false;
  String? _referralSearchError;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  void _onReferralPhoneChanged(String val) {
    final cleanDigits = val.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.isEmpty) {
      setState(() {
        _foundReferralDriver = null;
        _referralSearchError = null;
        _isSearchingReferral = false;
      });
      return;
    }

    if (cleanDigits.length < 10) {
      setState(() {
        _foundReferralDriver = null;
        _referralSearchError = null;
        _isSearchingReferral = false;
      });
      return;
    }

    _searchDriverByPhone(cleanDigits);
  }

  Future<void> _searchDriverByPhone(String cleanDigits) async {
    setState(() {
      _isSearchingReferral = true;
      _referralSearchError = null;
    });

    Map<String, dynamic>? match;
    for (var d in _drivers) {
      final dPhone = (d['telefono'] ?? '').toString().replaceAll(RegExp(r'\D'), '');
      if (dPhone.isNotEmpty && (dPhone == cleanDigits || dPhone.endsWith(cleanDigits) || cleanDigits.endsWith(dPhone))) {
        match = d;
        break;
      }
    }

    if (match == null) {
      try {
        final res = await Supabase.instance.client
            .from('conductores')
            .select('id, user_id, nombre, nombre_completo, placas, telefono, Aprobacion')
            .eq('telefono', cleanDigits)
            .maybeSingle();
        if (res != null) {
          match = Map<String, dynamic>.from(res);
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isSearchingReferral = false;
        if (match != null) {
          _foundReferralDriver = match;
          _referralSearchError = null;
        } else {
          _foundReferralDriver = null;
          _referralSearchError = 'No se encontró ningún conductor registrado con el número +52 $cleanDigits';
        }
      });
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final res = await Supabase.instance.client
          .from('conductores')
          .select('id, user_id, nombre, nombre_completo, placas, telefono, Aprobacion');
      
      final list = List<Map<String, dynamic>>.from(res);
      final approved = list.where((d) {
        final ap = (d['Aprobacion'] ?? d['aprobacion'] ?? '').toString().toLowerCase();
        final name = (d['nombre_completo'] ?? d['nombre'] ?? '').toString().trim();
        return name.isNotEmpty && (ap.isEmpty || ap == 'aprobado');
      }).toList();

      approved.sort((a, b) {
        final nameA = (a['nombre_completo'] ?? a['nombre'] ?? '').toString().toLowerCase();
        final nameB = (b['nombre_completo'] ?? b['nombre'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _drivers = approved;
        });
      }
    } catch (e) {
      print('Error cargando conductores para referidos: $e');
    }
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1000,
      );
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('No se pudo seleccionar la imagen: $e');
    }
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Selecciona tu foto de perfil',
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F3F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.black87),
                ),
                title: const Text('Tomar foto con la cámara', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F3F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Colors.black87),
                ),
                title: const Text('Elegir de la galería', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfileImage(ImageSource.gallery);
                },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  title: const Text('Eliminar foto', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _profileImage = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _referralPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final referralDigits = _referralPhoneController.text.trim().replaceAll(RegExp(r'\D'), '');

    // Validación obligatoria: Si ingresó un conductor referido, debe ser válido y debe subir su foto de perfil
    if (!_isLogin && referralDigits.isNotEmpty) {
      if (_foundReferralDriver == null) {
        _showErrorSnackBar('El número del conductor referido no es válido o no existe. Verifica el número o bórralo si no tienes referido.');
        return;
      }

      if (_profileImage == null) {
        _showErrorSnackBar('Para registrarte con un conductor referido, es obligatorio subir tu foto de perfil.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      if (_isLogin) {
        try {
          // Sign in
          print('Iniciando sesión con email: $email');
          await Supabase.instance.client.auth.signInWithPassword(
            email: email,
            password: password,
          );
          print('Sesión iniciada correctamente, procediendo a SplashRouterScreen');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sesión iniciada con éxito'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const SplashRouterScreen()),
              (route) => false,
            );
          }
        } on AuthException catch (e) {
          // Detectar si es un usuario migrado de Firebase
          if (e.message.contains('Unexpected failure') || 
              e.message.contains('Database error querying schema')) {
            try {
              final res = await Supabase.instance.client.functions.invoke(
                'migrate_firebase_user',
                body: {'email': email, 'password': password},
              );

              if (res.status == 200) {
                await Supabase.instance.client.auth.signInWithPassword(
                  email: email,
                  password: password,
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión iniciada con éxito. ¡Bienvenido de nuevo!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SplashRouterScreen()),
                    (route) => false,
                  );
                }
                return;
              } else {
                throw const AuthException('Credenciales incorrectas');
              }
            } catch (functionError) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al validar la cuenta. Por favor, intenta restablecer tu contraseña.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          }
          rethrow;
        }
      } else {
        // Sign up in auth.users
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );

        final userId = res.user?.id;

        if (userId != null) {
          String? photoUrl;
          if (_profileImage != null) {
            try {
              final fileName = 'perfil_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final storagePath = 'usuarios/$userId/$fileName';
              await Supabase.instance.client.storage.from('general').upload(
                storagePath,
                _profileImage!,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
              );
              photoUrl = Supabase.instance.client.storage.from('general').getPublicUrl(storagePath);
            } catch (uploadError) {
              print('Error al subir foto de perfil: $uploadError');
            }
          }

          final userData = <String, dynamic>{
            'user_id': userId,
            'nombre': name.isNotEmpty ? name : email.split('@').first,
            'correo': email,
            'telefono': phone,
            'isConductor': false,
            'usuario_activado': false,
          };

          if (photoUrl != null) {
            userData['imagen_perfil'] = photoUrl;
            userData['fotodeperfil'] = photoUrl;
            userData['perfilCompletado'] = true;
          }

          if (_foundReferralDriver != null && referralDigits.isNotEmpty) {
            userData['referido'] = referralDigits;
            userData['time_referido'] = DateTime.now().toUtc().toIso8601String();
          }

          // 1. Register in public.users as Passenger
          await Supabase.instance.client.from('users').insert(userData);
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text('Registro Exitoso'),
              content: const Text(
                'Te hemos enviado un correo de confirmación. Por favor, confirma tu cuenta para iniciar sesión.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _isLogin = true;
                      _passwordController.clear();
                      _nameController.clear();
                      _phoneController.clear();
                      _referralPhoneController.clear();
                      _foundReferralDriver = null;
                      _referralSearchError = null;
                      _profileImage = null;
                    });
                  },
                  child: const Text('Ir al Login', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        String errorMsg = error.message;
        if (errorMsg.contains('User already registered') || errorMsg.contains('already exists')) {
          errorMsg = 'Este correo ya está registrado. Por favor, inicia sesión.';
        } else if (errorMsg.contains('Invalid login credentials')) {
          errorMsg = 'El correo o la contraseña son incorrectos.';
        } else if (errorMsg.contains('Password should be at least 6 characters')) {
          errorMsg = 'La contraseña debe tener al menos 6 caracteres.';
        } else if (errorMsg.contains('Email rate limit exceeded')) {
          errorMsg = 'Demasiados intentos. Por favor, espera un momento.';
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

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar('Por favor ingresa tu correo electrónico para restablecer la contraseña.');
      return;
    }

    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(email)) {
      _showErrorSnackBar('Ingresa un correo electrónico válido');
      return;
    }

    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'taxiseguro://reset-callback/',
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text('Recuperación enviada'),
            content: Text(
              'Hemos enviado un enlace de restablecimiento a "$email". Por favor revisa tu bandeja de entrada o correo no deseado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('No se pudo enviar el correo de recuperación: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            fontFamily: 'Inter',
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
          style: const TextStyle(fontFamily: 'Inter', fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'Inter', color: Colors.black.withValues(alpha: 0.35)),
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

  Widget _buildReferralPhoneField() {
    final cleanDigits = _referralPhoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final bool hasReferral = cleanDigits.isNotEmpty;
    final bool isFound = _foundReferralDriver != null;
    final String? driverName = isFound
        ? ((_foundReferralDriver!['nombre_completo'] ?? _foundReferralDriver!['nombre'])?.toString().trim())
        : null;
    final String? driverPlacas = isFound ? _foundReferralDriver!['placas']?.toString().trim() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Conductor que te refirió',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(Opcional)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _referralPhoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: _onReferralPhoneChanged,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: 'Ej: 9671234567',
            hintStyle: TextStyle(
              fontFamily: 'Inter',
              color: Colors.black.withValues(alpha: 0.35),
              letterSpacing: 0.5,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.only(left: 18, right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '+52',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 20,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: _referralPhoneController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.black45),
                    onPressed: () {
                      _referralPhoneController.clear();
                      _onReferralPhoneChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF3F3F3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: isFound && _profileImage == null
                  ? const BorderSide(color: Colors.orangeAccent, width: 1.5)
                  : isFound && _profileImage != null
                      ? const BorderSide(color: Color(0xFF10B981), width: 1.5)
                      : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
          ),
        ),

        // Estado de búsqueda / Conductor encontrado / Error
        if (_isSearchingReferral) ...[
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                ),
                SizedBox(width: 8),
                Text(
                  'Verificando número de conductor...',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ] else if (isFound) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        driverPlacas != null && driverPlacas.isNotEmpty
                            ? 'Conductor: $driverName ($driverPlacas)'
                            : 'Conductor: $driverName',
                        style: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _profileImage == null ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      color: _profileImage == null ? Colors.orange[800] : Colors.green[700],
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _profileImage == null
                            ? 'Para validar tu registro con este referido, es obligatorio subir tu foto de perfil arriba.'
                            : 'Foto de perfil lista para registrarte con referido.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _profileImage == null ? Colors.orange[900] : Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else if (_referralSearchError != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[900], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _referralSearchError!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (hasReferral && cleanDigits.length < 10) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Ingresa los 10 dígitos (faltan ${10 - cleanDigits.length})',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black45),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.network(
              'https://images.pexels.com/photos/5357606/pexels-photo-5357606.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          
          // Form Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(height: 24),
                    
                    // Form Container
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta',
                              style: const TextStyle(
                                fontFamily: 'Google Sans',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin 
                                  ? 'Ingresa para continuar tu viaje.' 
                                  : 'Regístrate para usar Taxiseguro.',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Extra fields for Sign Up
                            if (!_isLogin) ...[
                              // Selector de Foto de Perfil
                              Center(
                                child: GestureDetector(
                                  onTap: _showImagePickerModal,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 86,
                                        height: 86,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFFF3F3F3),
                                          border: Border.all(
                                            color: _foundReferralDriver != null && _profileImage == null
                                                ? Colors.orangeAccent
                                                : Colors.black12,
                                            width: 2.5,
                                          ),
                                          image: _profileImage != null
                                              ? DecorationImage(
                                                  image: FileImage(_profileImage!),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: _profileImage == null
                                            ? const Icon(
                                                Icons.person_outline_rounded,
                                                size: 44,
                                                color: Colors.black38,
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF050505), // Modern Black
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 16,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Text(
                                  _foundReferralDriver != null && _profileImage == null
                                      ? 'Foto de perfil (Obligatoria para referidos *)'
                                      : (_profileImage != null ? 'Foto cargada con éxito' : 'Foto de perfil (Opcional)'),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _foundReferralDriver != null && _profileImage == null
                                        ? Colors.orange[800]
                                        : (_profileImage != null ? Colors.green[700] : Colors.black54),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              _buildTextField(
                                controller: _nameController,
                                label: 'Nombre completo',
                                hint: 'Ej: Mike Vázquez',
                              ),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'Número de teléfono',
                                hint: 'Ej: 8110002233',
                                keyboardType: TextInputType.phone,
                              ),
                            ],

                            // Email
                            _buildTextField(
                              controller: _emailController,
                              label: 'Correo electrónico',
                              hint: 'ejemplo@taxiseguro.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu correo electrónico';
                                }
                                final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegExp.hasMatch(value.trim())) {
                                  return 'Ingresa un correo electrónico válido';
                                }
                                return null;
                              },
                            ),

                            // Password
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
                                if (value == null || value.isEmpty) {
                                  return 'Por favor ingresa tu contraseña';
                                }
                                if (value.length < 6) {
                                  return 'La contraseña debe tener al menos 6 caracteres';
                                }
                                return null;
                              },
                            ),

                            // Campo de teléfono de conductor que te refirió (+52) hasta abajo
                            if (!_isLogin) ...[
                              _buildReferralPhoneField(),
                            ],
                            
                            if (_isLogin) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading ? null : _handleForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
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
                                    : Text(
                                        _isLogin ? 'Iniciar sesión' : 'Registrarse',
                                        style: const TextStyle(
                                          fontFamily: 'Google Sans',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Toggle Login/Register
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _formKey.currentState?.reset();
                                    _emailController.clear();
                                    _passwordController.clear();
                                    _nameController.clear();
                                    _phoneController.clear();
                                    _profileImage = null;
                                    _referralPhoneController.clear();
                                    _foundReferralDriver = null;
                                    _referralSearchError = null;
                                  });
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: _isLogin 
                                        ? '¿No tienes una cuenta? ' 
                                        : '¿Ya tienes una cuenta? ',
                                    style: const TextStyle(
                                      fontFamily: 'Inter', 
                                      color: Colors.black54, 
                                      fontSize: 14
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _isLogin ? 'Regístrate' : 'Inicia sesión',
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutQuad, delay: 200.ms),
                    
                    const SizedBox(height: 20),
                    
                    // Driver Registration Link
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const DriverRegistrationScreen()),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '¿Quieres ser conductor? Regístrate aquí',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ).animate().fade(duration: 500.ms, delay: 400.ms).slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutQuad, delay: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
