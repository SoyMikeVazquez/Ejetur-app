import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await _adminService.getAllUsers();
    if (mounted) {
      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((u) {
          final name = (u['nombre'] ?? u['Nombre'] ?? '').toString().toLowerCase();
          final email = (u['correo'] ?? u['email'] ?? '').toString().toLowerCase();
          final phone = (u['telefono'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Visualizador de Clientes',
          style: TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, correo o teléfono...',
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF2F2F2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),

          // Total Contador
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredUsers.length} usuarios encontrados',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 13),
                ),
                const Text(
                  'Taxiseguro Clientes',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),

          // Listado
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('No se encontraron usuarios'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final name = user['nombre'] ?? user['Nombre'] ?? 'Usuario Pasajero';
                          final email = user['correo'] ?? user['email'] ?? 'Sin correo';
                          final phone = user['telefono'] ?? 'Sin teléfono';
                          final isConductor = user['isConductor'] == true;
                          final isAdmin = user['isadmin'] == true || user['isAdmin'] == true;

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
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isAdmin
                                      ? Colors.black
                                      : isConductor
                                          ? const Color(0xFF050505)
                                          : const Color(0xFFF0F0F0),
                                  child: Icon(
                                    isAdmin
                                        ? Icons.admin_panel_settings
                                        : isConductor
                                            ? Icons.local_taxi
                                            : Icons.person,
                                    color: isAdmin
                                        ? const Color(0xFF050505)
                                        : isConductor
                                            ? Colors.black
                                            : Colors.black87,
                                    size: 24,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontFamily: 'Google Sans', fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isAdmin)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                                        child: const Text('ADMIN', style: TextStyle(color: Color(0xFF050505), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(email, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    Text('Tel: $phone', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fade(duration: 300.ms, delay: (index * 30).ms).slideY(begin: 0.05, end: 0);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
