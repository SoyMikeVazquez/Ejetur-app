import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver_privacy_policy_screen.dart';

class DriverFaceCaptureScreen extends StatefulWidget {
  const DriverFaceCaptureScreen({super.key});

  @override
  State<DriverFaceCaptureScreen> createState() => _DriverFaceCaptureScreenState();
}

class _DriverFaceCaptureScreenState extends State<DriverFaceCaptureScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isUploading = false;
  File? _capturedImage;

  Future<void> _takePhoto() async {
    try {
      final source = (Platform.isMacOS || Platform.isWindows || Platform.isLinux) 
          ? ImageSource.gallery 
          : ImageSource.camera;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 70,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image != null) {
        setState(() {
          _capturedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir la cámara: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndContinue() async {
    if (_capturedImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final fileName = 'face_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'conductores/${user.id}/$fileName';

      await _supabase.storage.from('general').upload(
            storagePath,
            _capturedImage!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl = _supabase.storage.from('general').getPublicUrl(storagePath);

      // Actualizar en tabla conductores y en la tabla users
      await _supabase.from('conductores').update({'imagen_perfil': publicUrl}).eq('user_id', user.id);
      await _supabase.from('users').update({'imagen_perfil': publicUrl}).eq('user_id', user.id);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverPrivacyPolicyScreen()),
        );
      }
    } catch (e) {
      print('Error subiendo foto de rostro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar la foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Foto de Perfil',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Necesitamos una foto tuya',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta foto se mostrará a los pasajeros para que puedan identificarte. Asegúrate de que haya buena iluminación y de que tu rostro se vea claramente.',
                style: TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Contenedor de la foto
              GestureDetector(
                onTap: _isUploading ? null : _takePhoto,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF050505), width: 4),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
                    ],
                  ),
                  child: ClipOval(
                    child: _capturedImage != null
                        ? Image.file(
                            _capturedImage!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt, size: 64, color: Colors.black38),
                              SizedBox(height: 12),
                              Text(
                                'Tocar para tomar foto',
                                style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const Spacer(),

              if (_capturedImage != null)
                TextButton.icon(
                  onPressed: _isUploading ? null : _takePhoto,
                  icon: const Icon(Icons.refresh, color: Colors.black87),
                  label: const Text('Tomar otra foto', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
                
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_capturedImage == null || _isUploading) ? null : _uploadAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF050505),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Guardar y Continuar',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
