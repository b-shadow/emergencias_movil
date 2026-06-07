import 'package:flutter/material.dart';
import 'vehiculos_screen.dart';
import 'editar_perfil_screen.dart';
import 'mis_solicitudes_screen.dart';
import 'notificaciones_screen.dart';
import '../services/auth_service.dart';
import '../services/tenant_service.dart';
import 'login_screen.dart';
import '../widgets/theme_toggle_button.dart';
import 'trabajador_ordenes_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AuthService _authService = AuthService();
  final TenantService _tenantService = TenantService();
  String? userName = '';
  String userRole = 'CLIENTE';
  String tenantLabel = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final name = await _authService.getUserName();
    final user = await _authService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      userName = name;
      userRole = user?.rol ?? 'CLIENTE';
    });
    if (userRole == 'TRABAJADOR') {
      try {
        final tenant = await _tenantService.obtenerTenantTrabajador();
        if (!mounted) return;
        setState(() {
          tenantLabel = (tenant['slug_tenant'] ?? tenant['nombre_tenant'] ?? '')
              .toString();
        });
      } catch (_) {}
    }
  }

  Future<void> _logout() async {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Deseas cerrar tu sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _authService.logout();
                if (!rootContext.mounted) return;
                Navigator.of(rootContext).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text('Sí, cerrar sesión',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 76,
            expandedHeight: 122,
            backgroundColor: const Color(0xFFFF5A5F),
            surfaceTintColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5A5F), Color(0xFFFF4B4F)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.shield,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Asistencia Vehicular',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const ThemeToggleButton(),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Salir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFFF5A5F),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  Text(
                    'Bienvenido, ${userName ?? 'Cliente'}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige una opción para continuar',
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withValues(alpha: 0.65),
                    ),
                  ),
                  if (userRole == 'TRABAJADOR' && tenantLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tenant: $tenantLabel',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (userRole == 'CLIENTE')
                    _buildEmergencyCard(
                      isDark: isDark,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const VehiculosScreen(
                                seleccionarPara: 'emergencia'),
                          ),
                        );
                      },
                    ),
                  if (userRole == 'TRABAJADOR')
                    _buildFeatureCard(
                      color: const Color(0xFF2563EB),
                      title: 'Mis Asignaciones',
                      subtitle: 'Gestiona ordenes, progreso y tracking',
                      icon: Icons.route,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const TrabajadorOrdenesScreen(),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  if (userRole == 'CLIENTE')
                    GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                      children: [
                        _buildFeatureCard(
                          color: const Color(0xFF7C3AED),
                          title: 'Editar Mi Perfil',
                          subtitle: 'Actualizar información personal',
                          icon: Icons.person_outline,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EditarPerfilScreen(),
                              ),
                            );
                            if (result == true) _loadUserName();
                          },
                        ),
                        _buildFeatureCard(
                          color: const Color(0xFF2563EB),
                          title: 'Gestionar Vehículos',
                          subtitle: 'Ver, editar y agregar vehículos',
                          icon: Icons.directions_car_outlined,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const VehiculosScreen(),
                              ),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          color: const Color(0xFFF59E0B),
                          title: 'Notificaciones',
                          subtitle: 'Ver mis notificaciones',
                          icon: Icons.notifications_none,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificacionesScreen(),
                              ),
                            );
                          },
                        ),
                        _buildFeatureCard(
                          color: const Color(0xFF22C55E),
                          title: 'Historial de Solicitudes',
                          subtitle: 'Ver solicitudes anteriores',
                          icon: Icons.history,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MisSolicitudesScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard({
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2B1F22) : const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF9F9F), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5A5F).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emergency,
                  color: Color(0xFFFF4B4F), size: 34),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergencia Vehicular',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF4B4F),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Solicita auxilio inmediato',
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Color(0xFFFF4B4F)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required Color color,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.arrow_forward_rounded, color: color, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
