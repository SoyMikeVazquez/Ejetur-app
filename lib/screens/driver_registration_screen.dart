import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_pending_approval_screen.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Datos Personales
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // 2. Datos del Vehículo
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _placasController = TextEditingController();
  final _anioController = TextEditingController();

  // 3. Archivos multimedia obligatorios
  File? _driverPhoto;
  File? _autoPhoto;
  File? _placasPhoto;
  File? _ineFrentePhoto;
  File? _ineReversoPhoto;
  File? _licenciaPhoto;

  bool _isLoading = false;
  String _loadingMessage = 'Creando cuenta...';
  bool _obscurePassword = true;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _modeloController.dispose();
    _colorController.dispose();
    _placasController.dispose();
    _anioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked != null) {
        setState(() {
          final file = File(picked.path);
          if (type == 'driver') _driverPhoto = file;
          if (type == 'auto') _autoPhoto = file;
          if (type == 'placas') _placasPhoto = file;
          if (type == 'ine_frente') _ineFrentePhoto = file;
          if (type == 'ine_reverso') _ineReversoPhoto = file;
          if (type == 'licencia') _licenciaPhoto = file;
        });
      }
    } catch (e) {
      _showErrorSnackBar('No se pudo seleccionar la imagen: $e');
    }
  }

  void _showImageSourceDialog(String type, String title) {
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
              Text(
                'Subir $title',
                style: const TextStyle(
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
                title: const Text('Tomar foto con la cámara', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera, type);
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
                title: const Text('Elegir de la galería', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery, type);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _uploadFileToStorage({
    required SupabaseClient client,
    required String userId,
    required File file,
    required String prefix,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${prefix}_${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'conductores/$userId/$fileName';

    // 1. Intentar subir al bucket 'general'
    try {
      await client.storage.from('general').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return client.storage.from('general').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Fallo al subir a general ($e). Intentando bucket alterno conductor-docs...');
      try {
        await client.storage.from('conductor-docs').upload(
          storagePath,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );
        return client.storage.from('conductor-docs').getPublicUrl(storagePath);
      } catch (e2) {
        debugPrint('Error en fallback conductor-docs: $e2');
        rethrow;
      }
    }
  }

  Future<void> _handleDriverRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    // Validación de fotografías obligatorias
    if (_driverPhoto == null) {
      _showErrorSnackBar('Por favor tómate o sube tu foto de perfil.');
      return;
    }
    if (_autoPhoto == null) {
      _showErrorSnackBar('Es obligatorio subir la fotografía del auto.');
      return;
    }
    if (_placasPhoto == null) {
      _showErrorSnackBar('Es obligatorio subir la fotografía de las placas del auto.');
      return;
    }
    if (_ineFrentePhoto == null) {
      _showErrorSnackBar('Es obligatorio subir la fotografía de tu INE (Frente).');
      return;
    }
    if (_ineReversoPhoto == null) {
      _showErrorSnackBar('Es obligatorio subir la fotografía de tu INE (Reverso / Parte trasera).');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Creando cuenta de usuario...';
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final modelo = _modeloController.text.trim();
    final anio = _anioController.text.trim();
    final color = _colorController.text.trim();
    final placas = _placasController.text.trim().toUpperCase();

    try {
      final client = Supabase.instance.client;

      // 1. Registro en Supabase Auth
      final res = await client.auth.signUp(
        email: email,
        password: password,
      );

      final userId = res.user?.id;
      if (userId == null) {
        throw const AuthException('No se pudo generar el identificador de usuario.');
      }

      // 2. Subida de archivos al Bucket de Supabase
      setState(() => _loadingMessage = 'Subiendo fotografía de perfil...');
      final String? driverPhotoUrl = await _uploadFileToStorage(
        client: client,
        userId: userId,
        file: _driverPhoto!,
        prefix: 'foto_perfil',
      );

      setState(() => _loadingMessage = 'Subiendo fotografía del vehículo...');
      final String? autoPhotoUrl = await _uploadFileToStorage(
        client: client,
        userId: userId,
        file: _autoPhoto!,
        prefix: 'foto_auto',
      );

      setState(() => _loadingMessage = 'Subiendo fotografía de las placas...');
      final String? placasPhotoUrl = await _uploadFileToStorage(
        client: client,
        userId: userId,
        file: _placasPhoto!,
        prefix: 'foto_placas',
      );

      setState(() => _loadingMessage = 'Subiendo INE (Frente)...');
      final String? ineFrenteUrl = await _uploadFileToStorage(
        client: client,
        userId: userId,
        file: _ineFrentePhoto!,
        prefix: 'foto_ine_frente',
      );

      setState(() => _loadingMessage = 'Subiendo INE (Reverso)...');
      final String? ineReversoUrl = await _uploadFileToStorage(
        client: client,
        userId: userId,
        file: _ineReversoPhoto!,
        prefix: 'foto_ine_reverso',
      );

      String? licenciaPhotoUrl;
      if (_licenciaPhoto != null) {
        setState(() => _loadingMessage = 'Subiendo licencia de conducir...');
        licenciaPhotoUrl = await _uploadFileToStorage(
          client: client,
          userId: userId,
          file: _licenciaPhoto!,
          prefix: 'foto_licencia',
        );
      }

      setState(() => _loadingMessage = 'Guardando expediente en base de datos...');

      // 3. Registrar en public.users
      await client.from('users').upsert({
        'user_id': userId,
        'nombre': name,
        'correo': email,
        'telefono': phone,
        'isConductor': true,
        'imagen_perfil': driverPhotoUrl,
        'fotodeperfil': driverPhotoUrl,
        'usuario_activado': false,
      });

      // 4. Registrar en public.conductores con user_id como UUID
      final driverData = <String, dynamic>{
        'id': userId,
        'user_id': userId, // UUID del usuario que se está registrando
        'nombre': name,
        'nombre_completo': name,
        'correo': email,
        'telefono': phone,
        'marca': modelo.split(' ').first,
        'modelo': modelo,
        'modelo_auto': modelo,
        'ano': anio,
        'anio_auto': anio,
        'color': color,
        'color_auto': color,
        'placas': placas,
        'imagen_perfil': driverPhotoUrl,
        'foto_auto_url': autoPhotoUrl,
        'foto_placas_url': placasPhotoUrl,
        'ine_url': ineFrenteUrl,
        'ine_frente_url': ineFrenteUrl,
        'ine_reverso_url': ineReversoUrl,
        'licencia_url': licenciaPhotoUrl,
        'estatus': 'inactivo',
        'Aprobacion': 'Pendiente',
        'Perfi_terminado': true,
      };

      try {
        await client.from('conductores').insert(driverData);
      } catch (insertError) {
        debugPrint('Error al insertar con esquema extendido: $insertError. Probando con campos base...');
        // Intento con campos compatibles si alguna columna no existe aún en la tabla de Supabase
        final fallbackData = Map<String, dynamic>.from(driverData);
        fallbackData.remove('foto_auto_url');
        fallbackData.remove('foto_placas_url');
        fallbackData.remove('ine_frente_url');
        fallbackData.remove('ine_reverso_url');
        fallbackData.remove('modelo_auto');
        fallbackData.remove('color_auto');
        fallbackData.remove('anio_auto');
        await client.from('conductores').insert(fallbackData);
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('¡Solicitud Enviada con Éxito!'),
            content: const Text(
              'Tu registro como Conductor de EJETUR ha sido recibido con toda tu documentación (INE frente y reverso) y fotografías del vehículo.\n\nTu expediente pasará a validación por el equipo de administración.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const DriverPendingApprovalScreen(status: 'Pendiente')),
                  );
                },
                child: const Text('Continuar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        String errorMsg = error.message;
        if (errorMsg.contains('User already registered') || errorMsg.contains('already exists')) {
          errorMsg = 'Este correo ya está registrado. Por favor, inicia sesión.';
        } else if (errorMsg.contains('Password should be at least 6 characters')) {
          errorMsg = 'La contraseña debe tener al menos 6 caracteres.';
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Ocurrió un error al registrar los datos: $error');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.black, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            suffixIcon: suffixIcon,
          ),
          validator: validator,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildImageUploadTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final bool hasFile = file != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasFile ? const Color(0xFF86EFAC) : Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: hasFile ? const Color(0xFFDCFCE7) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            image: hasFile
                ? DecorationImage(
                    image: FileImage(file),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: !hasFile
              ? Icon(icon, color: Colors.black87, size: 24)
              : null,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          hasFile ? 'Foto lista para subir' : subtitle,
          style: TextStyle(
            fontSize: 12,
            color: hasFile ? const Color(0xFF16A34A) : Colors.black54,
            fontWeight: hasFile ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: hasFile ? Colors.white : const Color(0xFF050505),
            foregroundColor: hasFile ? Colors.black : Colors.white,
            side: BorderSide(color: hasFile ? Colors.black26 : Colors.black),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(
            hasFile ? 'Cambiar' : 'Subir',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Registro de Conductor',
          style: TextStyle(fontFamily: 'Google Sans', color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Logo y Presentación
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      height: 54,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    'Expediente de Alta EJETUR',
                    style: TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Ingresa tu información y documentos para verificación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 24),

                // 1. FOTO DE PERFIL DEL CONDUCTOR
                Center(
                  child: GestureDetector(
                    onTap: () => _showImageSourceDialog('driver', 'Foto del Conductor'),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF3F3F3),
                            border: Border.all(
                              color: _driverPhoto != null ? const Color(0xFF22C55E) : Colors.black12,
                              width: 3,
                            ),
                            image: _driverPhoto != null
                                ? DecorationImage(
                                    image: FileImage(_driverPhoto!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _driverPhoto == null
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  size: 52,
                                  color: Colors.black38,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF050505),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _driverPhoto != null ? 'Foto de perfil seleccionada' : 'Foto del Conductor (Obligatoria *)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _driverPhoto != null ? const Color(0xFF16A34A) : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // SECCIÓN 1: DATOS PERSONALES Y ACCESO
                const Text(
                  '1. Datos Personales y Acceso',
                  style: TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                _buildTextField(
                  controller: _nameController,
                  label: 'Nombre completo',
                  hint: 'Ej: Norberto Illán Gutiérrez',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre completo' : null,
                ),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Teléfono celular',
                  hint: 'Ej: 8141308022',
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Ingresa un número de 10 dígitos' : null,
                ),
                _buildTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  hint: 'conductor@ejetur.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu correo';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Ingresa un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Contraseña para la app',
                  hint: '••••••••',
                  isObscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black54,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                ),

                const SizedBox(height: 16),

                // SECCIÓN 2: INFORMACIÓN DEL VEHÍCULO
                const Text(
                  '2. Datos del Vehículo',
                  style: TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        controller: _modeloController,
                        label: 'Marca y Modelo',
                        hint: 'Ej: Tesla Model 3',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _anioController,
                        label: 'Año',
                        hint: '2025',
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _colorController,
                        label: 'Color del Auto',
                        hint: 'Gris oscuro',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _placasController,
                        label: 'Placas',
                        hint: '51S-660',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // SECCIÓN 3: FOTOGRAFÍAS Y DOCUMENTOS
                const Text(
                  '3. Fotografías del Auto y Documentación',
                  style: TextStyle(
                    fontFamily: 'Google Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sube fotos legibles del vehículo, placas e identificación oficial (ambos lados).',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),

                _buildImageUploadTile(
                  title: 'Fotografía del Auto *',
                  subtitle: 'Vista exterior frontal o lateral del vehículo',
                  icon: Icons.directions_car_outlined,
                  file: _autoPhoto,
                  onTap: () => _showImageSourceDialog('auto', 'Foto del Auto'),
                ),

                _buildImageUploadTile(
                  title: 'Fotografía de las Placas *',
                  subtitle: 'Foto nítida de las placas del vehículo',
                  icon: Icons.pin_outlined,
                  file: _placasPhoto,
                  onTap: () => _showImageSourceDialog('placas', 'Foto de las Placas'),
                ),

                _buildImageUploadTile(
                  title: 'Identificación Oficial (INE Frente) *',
                  subtitle: 'Foto clara del frente de tu credencial INE',
                  icon: Icons.badge_outlined,
                  file: _ineFrentePhoto,
                  onTap: () => _showImageSourceDialog('ine_frente', 'INE (Frente)'),
                ),

                _buildImageUploadTile(
                  title: 'Identificación Oficial (INE Reverso) *',
                  subtitle: 'Foto clara de la parte trasera de tu credencial INE',
                  icon: Icons.flip_to_back_outlined,
                  file: _ineReversoPhoto,
                  onTap: () => _showImageSourceDialog('ine_reverso', 'INE (Reverso)'),
                ),

                _buildImageUploadTile(
                  title: 'Licencia de Conducir (Vigente)',
                  subtitle: 'Foto de tu licencia de chofer / automovilista',
                  icon: Icons.card_membership_outlined,
                  file: _licenciaPhoto,
                  onTap: () => _showImageSourceDialog('licencia', 'Licencia de Conducir'),
                ),

                const SizedBox(height: 24),

                // Botón de Envío
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleDriverRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF050505),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Flexible(
                                child: Text(
                                  _loadingMessage,
                                  style: const TextStyle(fontSize: 14, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Registrar Conductor',
                            style: TextStyle(
                              fontFamily: 'Google Sans',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: const TextSpan(
                        text: '¿Ya estás registrado? ',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Inicia sesión',
                            style: TextStyle(
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
