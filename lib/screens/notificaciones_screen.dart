import 'package:flutter/material.dart';
import '../models/notificacion.dart';
import '../services/notificacion_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

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
  
  Notificacion? _notificacionSeleccionada;

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

  void _mostrarDetalle(Notificacion notificacion) {
    setState(() {
      _notificacionSeleccionada = notificacion;
    });
  }

  void _cerrarDetalle() {
    setState(() {
      _notificacionSeleccionada = null;
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
                Navigator.of(context).pop();
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6B6B),
        title: const Text(
          'Notificaciones',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarNotificaciones,
            tooltip: 'Refrescar',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar Sesión'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<NotificacionResponse>(
        future: _futureNotificaciones,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _cargarNotificaciones,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text('No hay datos'),
            );
          }

          final response = snapshot.data!;
          final notificaciones = response.items;

          return Column(
            children: [
              // Filtros
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const <ButtonSegment<String>>[
                          ButtonSegment<String>(
                            value: '',
                            label: Text('Todas'),
                          ),
                          ButtonSegment<String>(
                            value: 'NO_LEIDA',
                            label: Text('No Leídas'),
                          ),
                          ButtonSegment<String>(
                            value: 'LEIDA',
                            label: Text('Leídas'),
                          ),
                        ],
                        selected: <String>{_filtroEstado},
                        onSelectionChanged: (Set<String> newSelection) {
                          _cambiarFiltro(newSelection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Estadísticas
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        Text(
                          '${response.total}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          'No Leídas',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        Text(
                          '${response.noLeidas}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Lista de notificaciones
              Expanded(
                child: notificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No hay notificaciones'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: notificaciones.length,
                        itemBuilder: (context, index) {
                          final notif = notificaciones[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: notif.esNoLeida ? const Color(0xFFFF6B6B) : Colors.grey,
                                ),
                              ),
                              title: Text(
                                notif.titulo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: notif.esNoLeida ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    notif.mensaje,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${notif.fecha.toLocal().day}/${notif.fecha.toLocal().month}/${notif.fecha.toLocal().year} ${notif.fecha.toLocal().hour}:${notif.fecha.toLocal().minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'ver') {
                                    _mostrarDetalle(notif);
                                  } else if (value == 'marcar' && notif.esNoLeida) {
                                    _marcarComoLeida(notif.id);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
      // Modal de detalle
      floatingActionButton: _notificacionSeleccionada != null
          ? FloatingActionButton(
              onPressed: _cerrarDetalle,
              backgroundColor: Colors.black87,
              child: const Icon(Icons.close),
            )
          : null,
    );
  }
}
