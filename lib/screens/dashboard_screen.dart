import 'package:flutter/material.dart';
import 'vehiculos_screen.dart';
import 'editar_perfil_screen.dart';
import 'mis_solicitudes_screen.dart';
import 'notificaciones_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  String? userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    setState(() {
      userName = name;
    });
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Deseas cerrar tu sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Sí, cerrar sesión', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B6B),
        title: const Text(
          'Asistencia Vehicular',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Salir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF6B6B),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bienvenida
              Text(
                'Bienvenido, ${userName ?? 'Cliente'}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Elige una opción para continuar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              // Botón: Editar Mi Perfil
              _buildMenuCard(
                icon: Icons.person_outline,
                title: 'Editar Mi Perfil',
                subtitle: 'Actualizar información personal',
                color: const Color(0xFF6B46C1),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditarPerfilScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadUserName(); // Recargar nombre si se actualizó
                  }
                },
              ),
              const SizedBox(height: 20),

              // Botón: Gestionar Vehículos
              _buildMenuCard(
                icon: Icons.directions_car,
                title: 'Gestionar Vehículos',
                subtitle: 'Ver, editar y agregar tus vehículos',
                color: const Color(0xFF5C7CFA),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const VehiculosScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Botón: Solicitar Emergencia
              _buildMenuCard(
                icon: Icons.emergency,
                title: 'Emergencia Vehicular',
                subtitle: 'Solicita auxilio inmediato',
                color: const Color(0xFFFF6B6B),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const VehiculosScreen(seleccionarPara: 'emergencia'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Botón: Notificaciones
              _buildMenuCard(
                icon: Icons.notifications,
                title: 'Notificaciones',
                subtitle: 'Ver mis notificaciones',
                color: const Color(0xFFFFA94D),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificacionesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Botón: Ver Solicitudes
              _buildMenuCard(
                icon: Icons.history,
                title: 'Historial de Solicitudes',
                subtitle: 'Ver tus solicitudes anteriores',
                color: const Color(0xFF40C057),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const MisSolicitudesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.15),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.3),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
