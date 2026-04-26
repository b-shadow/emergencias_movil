import 'package:flutter/material.dart';
import '../models/notificacion.dart';
import '../services/notificacion_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../widgets/theme_toggle_button.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final NotificacionService _notificacionService = NotificacionService();
  final AuthService _authService = AuthService();

  late Future<NotificacionResponse> _futureNotificaciones;
  String _filtroEstado = ''; // '' = todas, 'NO_LEIDA', 'LEIDA'
  int _offset = 0;
  static const int _limit = 10;

  @override
  void initState() {
    super.initState();
    _cargarNotificaciones();
  }

  void _cargarNotificaciones() {
    setState(() {
      _futureNotificaciones = _notificacionService.obtenerMisNotificaciones(
        limit: _limit,
        offset: _offset,
        estadoLectura: _filtroEstado.isEmpty ? null : _filtroEstado,
      );
    });
  }

  void _cambiarFiltro(String estado) {
    setState(() {
      _filtroEstado = estado;
      _offset = 0;
    });
    _cargarNotificaciones();
  }

  Future<void> _marcarComoLeida(String idNotificacion) async {
    try {
      await _notificacionService.marcarComoLeida(idNotificacion);
      _cargarNotificaciones();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marcada como leída')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                Navigator.of(context).pop();
                await _authService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text('Sí, cerrar sesión',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDetalle(Notificacion notificacion) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                notificacion.titulo,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                notificacion.mensaje,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.78),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _formatFecha(notificacion.fecha),
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.58), fontSize: 12),
              ),
              if (notificacion.esNoLeida) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _marcarComoLeida(notificacion.id);
                    },
                    icon: const Icon(Icons.done),
                    label: const Text('Marcar como leída'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.toLocal().day}/${fecha.toLocal().month}/${fecha.toLocal().year} '
        '${fecha.toLocal().hour}:${fecha.toLocal().minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF5A5F),
        foregroundColor: Colors.white,
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarNotificaciones,
            tooltip: 'Refrescar',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<NotificacionResponse>(
        future: _futureNotificaciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 50, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error: ${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _cargarNotificaciones,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No hay datos'));
          }

          final response = snapshot.data!;
          final notificaciones = response.items;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF191C25) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                ),
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                    ),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: '',
                      label: Text('Todas'),
                      icon: Icon(Icons.list_alt_rounded, size: 16),
                    ),
                    ButtonSegment<String>(
                      value: 'NO_LEIDA',
                      label: Text('No leídas'),
                      icon: Icon(Icons.mark_email_unread_outlined, size: 16),
                    ),
                    ButtonSegment<String>(
                      value: 'LEIDA',
                      label: Text('Leídas'),
                      icon: Icon(Icons.done_all_rounded, size: 16),
                    ),
                  ],
                  selected: <String>{_filtroEstado},
                  onSelectionChanged: (Set<String> newSelection) {
                    _cambiarFiltro(newSelection.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Total',
                        value: '${response.total}',
                        color: const Color(0xFF4A5568),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        title: 'No leídas',
                        value: '${response.noLeidas}',
                        color: const Color(0xFFFF5A5F),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: notificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_off_outlined,
                              size: 54,
                              color: cs.onSurface.withOpacity(0.35),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No hay notificaciones',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: notificaciones.length,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemBuilder: (context, index) {
                          final notif = notificaciones[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF181B24)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: notif.esNoLeida
                                    ? const Color(0xFFFF8A8D).withOpacity(0.6)
                                    : cs.outlineVariant.withOpacity(0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(isDark ? 0.24 : 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(14, 10, 8, 10),
                              leading: Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: notif.esNoLeida
                                      ? const Color(0xFFFF5A5F)
                                      : cs.outlineVariant,
                                ),
                              ),
                              title: Text(
                                notif.titulo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: notif.esNoLeida
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notif.mensaje,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: cs.onSurface.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatFecha(notif.fecha),
                                      style: TextStyle(
                                        color: cs.onSurface.withOpacity(0.54),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'ver') {
                                    _mostrarDetalle(notif);
                                  } else if (value == 'marcar' &&
                                      notif.esNoLeida) {
                                    _marcarComoLeida(notif.id);
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'ver',
                                    child: Text('Ver detalle'),
                                  ),
                                  if (notif.esNoLeida)
                                    const PopupMenuItem<String>(
                                      value: 'marcar',
                                      child: Text('Marcar como leída'),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF191C25) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.68),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
