import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/admin_service.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await _adminService.getAllUsers();
    if (mounted) {
      setState(() {
        _allUsers = users;
        _admins = users.where((u) => u['isadmin'] == true || u['isAdmin'] == true).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _assignAdminRole() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un correo')),
      );
      return;
    }

    final targetUser = _allUsers.firstWhere(
      (u) => (u['correo'] ?? u['email'] ?? '').toString().toLowerCase() == email,
      orElse: () => {},
    );

    if (targetUser.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró ningún usuario con ese correo')),
      );
      return;
    }

    final userId = targetUser['user_id']?.toString() ?? targetUser['id']?.toString();
    if (userId == null) return;

    setState(() => _isLoading = true);
    final success = await _adminService.toggleAdminRole(userId, true);
    _emailController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '¡Rol de Super Admin otorgado con éxito!' : 'Error al asignar rol'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      _loadData();
    }
  }

  Future<void> _revokeAdminRole(String userId, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Revocar permisos?'),
        content: Text('Se removerán los permisos de Super Administrador para "$name".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _adminService.toggleAdminRole(userId, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Permisos de admin revocados' : 'Error al revocar rol'),
            backgroundColor: success ? Colors.black87 : Colors.red,
          ),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Creador de Super Admins',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Tarjeta de Asignación Rápida
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF050505),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shield, color: Colors.black, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Asignar Nuevo Super Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Google Sans',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Escribe el correo electrónico del usuario registrado para convertirlo en Super Administrador con acceso completo.',
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'ejemplo@taxiseguro.mx',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.white12,
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF050505)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _assignAdminRole,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF050505),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: const Text(
                            'Otorgar Permisos de Super Admin',
                            style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 28),

                // Lista de Super Administradores Actuales
                const Text(
                  'Super Administradores Actuales',
                  style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_admins.length} administradores con privilegios completos',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 14),

                if (_admins.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay administradores registrados')))
                else
                  ..._admins.map((admin) {
                    final name = admin['nombre'] ?? admin['Nombre'] ?? 'Administrador';
                    final email = admin['correo'] ?? admin['email'] ?? 'Sin correo';
                    final userId = admin['user_id']?.toString() ?? admin['id']?.toString() ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          leading: const CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.black,
                            child: Icon(Icons.admin_panel_settings, color: Color(0xFF050505), size: 24),
                          ),
                          title: Text(name, style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text(email, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            tooltip: 'Revocar permisos',
                            onPressed: () => _revokeAdminRole(userId, name),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
