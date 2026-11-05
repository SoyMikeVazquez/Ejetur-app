import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/rating_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;
  const ProfileScreen({super.key, this.showBackButton = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _isLoading = false;
  bool _isSaving = false;
  // final String _selectedPaymentMethod = 'Efectivo';
  String? _profileImageUrl;
  double _userRating = 5.0;

  // Lista simulada de métodos de pago guardados
  /*
  final List<Map<String, String>> _paymentMethods = [
    {'type': 'cash', 'title': 'Efectivo', 'subtitle': 'Pagar en efectivo al finalizar'},
    {'type': 'card', 'title': 'Visa **** 4242', 'subtitle': 'Vence 12/28'},
    {'type': 'card', 'title': 'Mastercard **** 8819', 'subtitle': 'Vence 05/27'},
  ];
*/

  @override
  void initState() {
    super.initState();
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? '';
    final displayName = email.split('@')[0];

    _nameController = TextEditingController(text: displayName);
    _emailController = TextEditingController(text: email);
    _phoneController = TextEditingController(text: '+52 81 1234 5678');

    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          if (response['nombre'] != null && (response['nombre'] as String).isNotEmpty) {
            _nameController.text = response['nombre'];
          }
          if (response['telefono'] != null && (response['telefono'] as String).isNotEmpty) {
            _phoneController.text = response['telefono'];
          }
          if (response['imagen_perfil'] != null && (response['imagen_perfil'] as String).isNotEmpty) {
            _profileImageUrl = response['imagen_perfil'];
          }
        });
      }

      // Intentar cargar la calificación promedio desde la tabla 'ratings'
      try {
        final ratingService = RatingService();
        final stats = await ratingService.getUserRatingStats(user.id);
        if (mounted) {
          setState(() {
            _userRating = stats['average'] as double;
          });
        }
      } catch (e) {
        print('Error al cargar ratings: $e');
      }

    } catch (e) {
      print('Error al cargar perfil de Supabase: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image == null) return;
      
      setState(() {
        _isLoading = true;
      });
      
      final File file = File(image.path);
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      
      final fileName = 'perfil_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'usuarios/${user.id}/$fileName';
      
      await _supabase.storage.from('general').upload(
        storagePath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      
      final String publicUrl = _supabase.storage.from('general').getPublicUrl(storagePath);
      
      await _supabase.from('users').update({
        'imagen_perfil': publicUrl,
        'fotodeperfil': publicUrl,
        'perfilCompletado': true,
      }).eq('user_id', user.id);
      
      setState(() {
        _profileImageUrl = publicUrl;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.from('users').update({
        'nombre': _nameController.text.trim(),
        'telefono': _phoneController.text.trim(),
      }).eq('user_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado exitosamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar perfil: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /* void _showAddPaymentMethodModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Agregar tarjeta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Número de tarjeta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'MM/AA',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Método de pago agregado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Guardar tarjeta'),
                ),
              ),
            ],
          ),
        );
      },
    );
  } */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontFamily: 'Google Sans', color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 120.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Header
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF050505), width: 3),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: Colors.black,
                                  child: _profileImageUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            _profileImageUrl!,
                                            width: 88,
                                            height: 88,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : CircleAvatar(
                                          radius: 44,
                                          backgroundColor: Colors.grey[200],
                                          child: const Icon(Icons.person, size: 50, color: Colors.black54),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _pickAndUploadImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                                const SizedBox(width: 6),
                                Text(
                                  _userRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Promedio',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Datos Personales
                    const Text(
                      'Información Personal',
                      style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5)),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Nombre
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color(0xFFF3F3F3),
                            ),
                            validator: (val) => val == null || val.isEmpty ? 'Ingresa tu nombre' : null,
                          ),
                          const SizedBox(height: 16),

                          // Correo (deshabilitado / lectura)
                          TextFormField(
                            controller: _emailController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color(0xFFE0E0E0),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Teléfono
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Teléfono',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: const Color(0xFFF3F3F3),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Métodos de Pago Section (Oculto)
                    /*
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Métodos de Pago',
                          style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        TextButton.icon(
                          onPressed: _showAddPaymentMethodModal,
                          icon: const Icon(Icons.add, size: 18, color: Colors.black),
                          label: const Text('Agregar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 15, offset: Offset(0, 5)),
                        ],
                      ),
                      child: Column(
                        children: _paymentMethods.map((method) {
                          final isSelected = _selectedPaymentMethod == method['title'];
                          return RadioListTile<String>(
                            value: method['title']!,
                            groupValue: _selectedPaymentMethod,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedPaymentMethod = val;
                                });
                              }
                            },
                            title: Text(
                              method['title']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            subtitle: Text(method['subtitle']!),
                            secondary: Icon(
                              method['type'] == 'cash' ? Icons.money : Icons.credit_card,
                              color: isSelected ? Colors.black : Colors.grey[600],
                            ),
                            activeColor: Colors.black,
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 40),
                    */

                    // Botón Guardar Cambios
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF050505), // Modern Black
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(fontFamily: 'Google Sans', fontSize: 18, fontWeight: FontWeight.bold),
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
