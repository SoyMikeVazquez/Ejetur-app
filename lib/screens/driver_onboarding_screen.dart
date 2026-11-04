import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'driver_pending_approval_screen.dart';
import 'auth_screen.dart';

class DriverOnboardingScreen extends StatefulWidget {
  final bool isAdminContext;
  final SupabaseClient? isolatedClient;
  const DriverOnboardingScreen({super.key, this.isAdminContext = false, this.isolatedClient});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Paso 1: Vehículo
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _placasController = TextEditingController();
  final _anioController = TextEditingController();

  // Paso 2: Documentos (Imágenes)
  File? _ineFile;
  File? _licenciaFile;
  File? _seguroFile;
  File? _tarjetaFile;

  String? _ineUrl;
  String? _licenciaUrl;
  String? _seguroUrl;
  String? _tarjetaUrl;

  final ImagePicker _picker = ImagePicker();

  // Paso 3: Banco
  final _bancoController = TextEditingController();
  final _cuentaController = TextEditingController();
  final _clabeController = TextEditingController();

  @override
  void dispose() {
    _modeloController.dispose();
    _colorController.dispose();
    _placasController.dispose();
    _anioController.dispose();
    _bancoController.dispose();
    _cuentaController.dispose();
    _clabeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // 1. Validar Paso 0: Vehículo
    if (_currentStep == 0) {
      if (_modeloController.text.trim().isEmpty ||
          _anioController.text.trim().isEmpty ||
          _colorController.text.trim().isEmpty ||
          _placasController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor completa todos los campos del vehículo.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // 2. Validar Paso 1: Documentos
    if (_currentStep == 1) {
      final List<String> missingDocs = [];
      if (_ineUrl == null) missingDocs.add('Identificación Oficial (INE)');
      if (_licenciaUrl == null) missingDocs.add('Licencia de Conducir');
      if (_seguroUrl == null) missingDocs.add('Póliza de Seguro');
      if (_tarjetaUrl == null) missingDocs.add('Tarjeta de Circulación');

      if (missingDocs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falta subir: ${missingDocs.join(", ")}. Todos los documentos son obligatorios.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    // 3. Validar Paso 2: Banco
    if (_currentStep == 2) {
      if (_bancoController.text.trim().isEmpty ||
          _cuentaController.text.trim().isEmpty ||
          _clabeController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor ingresa todos los datos bancarios.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _submitForm();
      return;
    }

    setState(() => _currentStep++);
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickAndUploadImage(String documentType) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image == null) return;
      
      setState(() => _isLoading = true);
      
      final client = widget.isolatedClient ?? Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final fileBytes = await image.readAsBytes();
      final fileExtension = image.name.split('.').last;
      final fileName = '${userId}_${documentType}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storagePath = 'conductores/$userId/$fileName';
      
      await client.storage
          .from('general')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );
          
      final publicUrl = client.storage
          .from('general')
          .getPublicUrl(storagePath);
          
      setState(() {
        final localFile = File(image.path);
        if (documentType == 'ine') {
          _ineFile = localFile;
          _ineUrl = publicUrl;
        } else if (documentType == 'licencia') {
          _licenciaFile = localFile;
          _licenciaUrl = publicUrl;
        } else if (documentType == 'seguro') {
          _seguroFile = localFile;
          _seguroUrl = publicUrl;
        } else if (documentType == 'tarjeta') {
          _tarjetaFile = localFile;
          _tarjetaUrl = publicUrl;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento cargado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al seleccionar/subir documento: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm() async {
    final client = widget.isolatedClient ?? Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final bool isAllComplete = 
        _modeloController.text.trim().isNotEmpty &&
        _anioController.text.trim().isNotEmpty &&
        _colorController.text.trim().isNotEmpty &&
        _placasController.text.trim().isNotEmpty &&
        _ineUrl != null &&
        _licenciaUrl != null &&
        _seguroUrl != null &&
        _tarjetaUrl != null &&
        _bancoController.text.trim().isNotEmpty &&
        _cuentaController.text.trim().isNotEmpty &&
        _clabeController.text.trim().isNotEmpty;

    if (!isAllComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes completar todos los campos y subir todos los documentos requeridos.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await client.from('conductores').update({
        'modelo_auto': _modeloController.text.trim(),
        'color_auto': _colorController.text.trim(),
        'placas': _placasController.text.trim(),
        'anio_auto': _anioController.text.trim(),
        'ine_url': _ineUrl,
        'licencia_url': _licenciaUrl,
        'seguro_url': _seguroUrl,
        'tarjeta_circulacion_url': _tarjetaUrl,
        'banco': _bancoController.text.trim(),
        'cuenta_bancaria': _cuentaController.text.trim(),
        'clabe': _clabeController.text.trim(),
        'estatus': widget.isAdminContext ? 'activo' : 'inactivo',
        'Perfi_terminado': true,
        'Aprobacion': widget.isAdminContext ? 'Aprobado' : 'Pendiente',
      }).eq('user_id', userId);

      if (mounted) {
        if (widget.isAdminContext) {
          // Disponer el cliente temporal
          widget.isolatedClient?.dispose();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('¡Conductor dado de alta!'),
              content: const Text('Se ha registrado el conductor con todos sus documentos como ACTIVO.\n\nTu sesión de Administrador sigue activa.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // cerrar dialogo
                    Navigator.of(context).pop(); // cerrar onboarding
                  },
                  child: const Text('Entendido'),
                )
              ],
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const DriverPendingApprovalScreen(status: 'Pendiente'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar datos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Completar Perfil', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        automaticallyImplyLeading: false, // El usuario no puede ir atrás sin terminar o cerrar sesión
        leading: widget.isAdminContext ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            widget.isolatedClient?.dispose();
            Navigator.of(context).pop();
          },
        ) : null,
        actions: [
          if (!widget.isAdminContext)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                }
              },
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : Stepper(
              type: StepperType.horizontal,
              currentStep: _currentStep,
              onStepContinue: _nextStep,
              onStepCancel: _previousStep,
              controlsBuilder: (BuildContext context, ControlsDetails details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Row(
                    children: <Widget>[
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton(
                              onPressed: details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black, width: 2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Text('Atrás', style: TextStyle(color: Colors.black, fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF050505), // Modern Black
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              elevation: 0,
                            ),
                            child: Text(_currentStep == 2 ? 'Finalizar' : 'Continuar', style: const TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Vehículo'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      _buildTextField(_modeloController, 'Modelo del Auto', 'Ej: Nissan Versa'),
                      _buildTextField(_anioController, 'Año', 'Ej: 2023', TextInputType.number),
                      _buildTextField(_colorController, 'Color', 'Ej: Blanco'),
                      _buildTextField(_placasController, 'Placas', 'Ej: XYZ-8921'),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Documentos'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sube fotos claras de tus documentos oficiales. Se guardarán en la nube de forma segura.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 16),
                      _buildImageUploader('ine', 'Identificación Oficial (INE)', _ineFile != null),
                      _buildImageUploader('licencia', 'Licencia de Conducir', _licenciaFile != null),
                      _buildImageUploader('seguro', 'Póliza de Seguro', _seguroFile != null),
                      _buildImageUploader('tarjeta', 'Tarjeta de Circulación', _tarjetaFile != null),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Banco'),
                  isActive: _currentStep >= 2,
                  content: Column(
                    children: [
                      _buildTextField(_bancoController, 'Nombre del Banco', 'Ej: BBVA'),
                      _buildTextField(_cuentaController, 'Número de Cuenta', '10 dígitos', TextInputType.number),
                      _buildTextField(_clabeController, 'CLABE Interbancaria', '18 dígitos', TextInputType.number),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, [TextInputType type = TextInputType.text]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildImageUploader(String type, String title, bool isUploaded) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _pickAndUploadImage(type),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isUploaded ? const Color(0xFF050505).withValues(alpha: 0.1) : const Color(0xFFF3F3F3),
            border: Border.all(color: isUploaded ? const Color(0xFF050505) : Colors.transparent),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle : Icons.cloud_upload,
                color: isUploaded ? Colors.green : Colors.black54,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
                    color: isUploaded ? Colors.green.shade700 : Colors.black87,
                  ),
                ),
              ),
              if (!isUploaded)
                const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
