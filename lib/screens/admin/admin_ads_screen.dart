import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ad.dart';

class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _ads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('ads').select().order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _ads = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading ads: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAd(int id) async {
    try {
      await _supabase.from('ads').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anuncio eliminado')));
        _loadAds();
      }
    } catch (e) {
      debugPrint('Error deleting ad: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  void _showAdBottomSheet([Map<String, dynamic>? ad]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdFormBottomSheet(
        ad: ad,
        onSaved: () {
          _loadAds();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Administrador de Anuncios', style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _ads.isEmpty
              ? const Center(child: Text('No hay anuncios registrados', style: TextStyle(fontFamily: 'Google Sans', fontSize: 16, color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _ads.length,
                  itemBuilder: (context, index) {
                    final ad = _ads[index];
                    final phone = Ad.parsePhone(ad['numero_contacto']);
                    final wa = Ad.parsePhone(ad['whatsapp']);
                    final int vistas = (ad['visitas'] ?? ad['vistas'] as num?)?.toInt() ?? 0;
                    final int clicksContacto = (ad['clicks_contacto'] as num?)?.toInt() ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (ad['imagen_ads'] != null && ad['imagen_ads'].toString().isNotEmpty)
                            Image.network(
                              ad['imagen_ads'],
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              ),
                            )
                          else
                            Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: const Center(child: Text('Sin Imagen', style: TextStyle(color: Colors.grey))),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ad['titulo_ads'] ?? 'Sin título',
                                        style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      const SizedBox(height: 6),
                                      if (ad['descripcion_ads'] != null && ad['descripcion_ads'].toString().isNotEmpty)
                                        Text(
                                          ad['descripcion_ads'],
                                          style: const TextStyle(fontFamily: 'Inter', color: Colors.black87),
                                        ),
                                      const SizedBox(height: 12),
                                      
                                      // Métricas de visualizaciones y clics
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.visibility_rounded, size: 14, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$vistas Vistas',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.touch_app_rounded, size: 14, color: Colors.green),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$clicksContacto Clics contacto',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (phone != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.grey[300]!),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.phone_rounded, size: 13, color: Colors.black54),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    phone,
                                                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (wa != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.4)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.chat_bubble_rounded, size: 13, color: Color(0xFF25D366)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    wa,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E7E34)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showAdBottomSheet(ad),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Eliminar Anuncio'),
                                            content: const Text('¿Estás seguro de eliminar este anuncio?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                                              TextButton(
                                                onPressed: () => Navigator.pop(c, true),
                                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          _deleteAd(ad['id']);
                                        }
                                      },
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAdBottomSheet(),
        backgroundColor: const Color(0xFF050505),
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nuevo Anuncio', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _AdFormBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? ad;
  final VoidCallback onSaved;

  const _AdFormBottomSheet({this.ad, required this.onSaved});

  @override
  State<_AdFormBottomSheet> createState() => _AdFormBottomSheetState();
}

class _AdFormBottomSheetState extends State<_AdFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  
  File? _selectedImage;
  String? _existingImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.ad != null) {
      _titleController.text = widget.ad!['titulo_ads'] ?? '';
      _descController.text = widget.ad!['descripcion_ads'] ?? '';
      _phoneController.text = Ad.parsePhone(widget.ad!['numero_contacto']) ?? '';
      _whatsappController.text = Ad.parsePhone(widget.ad!['whatsapp']) ?? '';
      _existingImageUrl = widget.ad!['imagen_ads'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      final sizeMb = file.lengthSync() / (1024 * 1024);
      if (sizeMb > 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('La imagen debe pesar menos de 2MB')),
          );
        }
        return;
      }
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _saveAd() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (widget.ad == null && _selectedImage == null && _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una imagen para el anuncio.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      String? imageUrl = _existingImageUrl;
      final supabase = Supabase.instance.client;

      if (_selectedImage != null) {
        final ext = _selectedImage!.path.split('.').last;
        final fileName = 'ad_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await supabase.storage.from('general').upload('ads/$fileName', _selectedImage!);
        imageUrl = supabase.storage.from('general').getPublicUrl('ads/$fileName');
      }

      num? phoneNum;
      final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.isNotEmpty) {
        phoneNum = num.tryParse(cleanPhone);
      }

      num? waNum;
      final cleanWa = _whatsappController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanWa.isNotEmpty) {
        waNum = num.tryParse(cleanWa);
      }

      final payload = {
        'titulo_ads': _titleController.text.trim(),
        'descripcion_ads': _descController.text.trim(),
        'imagen_ads': imageUrl,
        'numero_contacto': phoneNum,
        'whatsapp': waNum,
      };

      if (widget.ad == null) {
        await supabase.from('ads').insert(payload);
      } else {
        await supabase.from('ads').update(payload).eq('id', widget.ad!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anuncio guardado con éxito')),
        );
      }
    } catch (e) {
      debugPrint('Error saving ad: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de arrastre superior
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Cabecera con título y botón de cierre
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.ad == null ? 'Nuevo Anuncio' : 'Editar Anuncio',
                    style: const TextStyle(
                      fontFamily: 'Google Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector de Imagen
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_selectedImage != null)
                        Image.file(_selectedImage!, fit: BoxFit.cover)
                      else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                        Image.network(_existingImageUrl!, fit: BoxFit.cover)
                      else
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.add_photo_alternate_rounded, size: 36, color: Colors.black87),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Toca para subir imagen',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF050505).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Medida recomendada: 600 x 360 px (Horizontal) • Máx. 2MB',
                                style: TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),

                      // Overlay con etiqueta si hay imagen cargada
                      if (_selectedImage != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                        Positioned(
                          bottom: 10,
                          left: 10,
                          right: 10,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Recomendado: 600 x 360 px',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF050505),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, size: 13, color: Colors.black),
                                    SizedBox(width: 4),
                                    Text(
                                      'Cambiar',
                                      style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Campo: Título con límite de caracteres
              TextFormField(
                controller: _titleController,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: 'Título del anuncio',
                  hintText: 'Ej. Renta de Equipo',
                  helperText: 'Máx. 30 caracteres (se muestra en 1 línea en el Home)',
                  helperStyle: const TextStyle(fontSize: 11, color: Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'El título es obligatorio' : null,
              ),
              const SizedBox(height: 14),

              // Campo: Descripción con límite de caracteres
              TextFormField(
                controller: _descController,
                maxLength: 70,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Descripción del anuncio',
                  hintText: 'Ej. Andamios y herramientas en San Cristóbal',
                  helperText: 'Máx. 70 caracteres (se muestra en máx. 2 líneas en el Home)',
                  helperStyle: const TextStyle(fontSize: 11, color: Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.subtitles_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Campo: Teléfono de contacto
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'Teléfono para llamadas',
                  hintText: 'Ej. 9671511860',
                  helperText: 'Activa el botón "Llamar" en el anuncio (opcional)',
                  helperStyle: const TextStyle(fontSize: 11, color: Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: 14),

              // Campo: WhatsApp
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                decoration: InputDecoration(
                  labelText: 'Número de WhatsApp',
                  hintText: 'Ej. 9671511860',
                  helperText: 'Activa el botón "WhatsApp" en el anuncio (opcional)',
                  helperStyle: const TextStyle(fontSize: 11, color: Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF25D366)),
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveAd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF050505),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Guardar Anuncio',
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
