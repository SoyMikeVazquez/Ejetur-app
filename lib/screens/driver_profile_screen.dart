import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/driver_profile_service.dart';
import 'auth_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _profileService = DriverProfileService();
  bool _isLoading = true;
  bool _isEditing = false;
  String? _driverId;

  // Controladores de Perfil
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();

  // Controladores de Vehículo
  final _modeloController = TextEditingController();
  final _colorController = TextEditingController();
  final _anioController = TextEditingController();
  final _placasController = TextEditingController();

  // Controladores Bancarios
  final _bancoController = TextEditingController();
  final _cuentaController = TextEditingController();
  final _clabeController = TextEditingController();

  // Controladores de Documentos (URLs)
  final _ineController = TextEditingController();
  final _licenciaController = TextEditingController();
  final _seguroController = TextEditingController();
  final _tarjetaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _driverId = Supabase.instance.client.auth.currentUser?.id;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_driverId == null) return;
    final data = await _profileService.getDriverProfile(_driverId!);
    if (data != null && mounted) {
      setState(() {
        _nombreController.text = data['nombre_completo'] ?? '';
        _telefonoController.text = data['telefono'] ?? '';
        
        _modeloController.text = data['modelo_auto'] ?? '';
        _colorController.text = data['color_auto'] ?? '';
        _anioController.text = data['anio_auto'] ?? '';
        _placasController.text = data['placas'] ?? '';
        
        _bancoController.text = data['banco'] ?? '';
        _cuentaController.text = data['cuenta_bancaria'] ?? '';
        _clabeController.text = data['clabe'] ?? '';
        
        _ineController.text = data['ine_url'] ?? '';
        _licenciaController.text = data['licencia_url'] ?? '';
        _seguroController.text = data['seguro_url'] ?? '';
        _tarjetaController.text = data['tarjeta_circulacion_url'] ?? '';
        
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_driverId == null) return;
    setState(() => _isLoading = true);
    
    final updates = {
      'nombre_completo': _nombreController.text.trim(),
      'telefono': _telefonoController.text.trim(),
      'modelo_auto': _modeloController.text.trim(),
      'color_auto': _colorController.text.trim(),
      'anio_auto': _anioController.text.trim(),
      'placas': _placasController.text.trim(),
      'banco': _bancoController.text.trim(),
      'cuenta_bancaria': _cuentaController.text.trim(),
      'clabe': _clabeController.text.trim(),
    };
    
    final success = await _profileService.updateDriverProfile(_driverId!, updates);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (success) _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Perfil actualizado exitosamente' : 'Error al actualizar perfil'),
          backgroundColor: success ? Colors.amber[700] : Colors.red,
        ),
      );
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber[700], size: 28),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 24)),
        backgroundColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (!_isLoading)
            if (!_isEditing)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                tooltip: 'Editar Perfil',
                onPressed: () => setState(() => _isEditing = true),
              )
            else
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                tooltip: 'Cancelar Edición',
                onPressed: () {
                  setState(() => _isEditing = false);
                  _loadProfile(); // Recargar para descartar cambios
                },
              ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle('Información Personal', Icons.person),
                  _buildField(_nombreController, 'Nombre Completo'),
                  _buildField(_telefonoController, 'Teléfono', TextInputType.phone),
                  
                  _buildSectionTitle('Información del Vehículo', Icons.directions_car),
                  _buildField(_modeloController, 'Modelo del Vehículo (ej. Versa)'),
                  _buildField(_anioController, 'Año', TextInputType.number),
                  _buildField(_colorController, 'Color'),
                  _buildField(_placasController, 'Placas'),
                  
                  _buildSectionTitle('Datos Bancarios', Icons.account_balance),
                  _buildField(_bancoController, 'Nombre del Banco'),
                  _buildField(_cuentaController, 'Número de Cuenta', TextInputType.number),
                  _buildField(_clabeController, 'CLABE Interbancaria', TextInputType.number),
                  
                  _buildSectionTitle('Documentos', Icons.folder),
                  _buildDocumentImage('INE / Identificación', _ineController.text),
                  _buildDocumentImage('Licencia de Conducir', _licenciaController.text),
                  _buildDocumentImage('Póliza de Seguro', _seguroController.text),
                  _buildDocumentImage('Tarjeta de Circulación', _tarjetaController.text),
                  
                  if (_isEditing) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF050505), // Modern Black
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        child: const Text('Guardar Cambios', style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  if (!_isEditing) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión', style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 120), // padding extra para que no estorbe el menu liquid glass
                ],
              ),
            ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, [TextInputType type = TextInputType.text]) {
    if (!_isEditing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                controller.text.isEmpty ? 'No especificado' : controller.text, 
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDocumentImage(String label, String url) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
