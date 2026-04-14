import 'package:flutter/material.dart';
import '../models/solicitud.dart';
import '../services/solicitud_service.dart';
import 'detalle_solicitud_screen.dart';

class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({Key? key}) : super(key: key);

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  final SolicitudService _solicitudService = SolicitudService();
  List<Solicitud> _solicitudes = [];
  bool _isLoading = true;
  String _ordenamiento = 'reciente'; // 'reciente' o 'antiguo'

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final solicitudes = await _solicitudService.obtenerSolicitudes();
      setState(() {
        _solicitudes = solicitudes;
        _ordenarSolicitudes();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar solicitudes: $e')),
      );
    }
  }

  void _ordenarSolicitudes() {
    if (_ordenamiento == 'reciente') {
      _solicitudes.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } else {
      _solicitudes.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
    }
  }

  void _cambiarOrdenamiento(String valor) {
    setState(() {
      _ordenamiento = valor;
      _ordenarSolicitudes();
    });
  }

  String _obtenerEstadoColor(String estado) {
    switch (estado) {
      case 'REGISTRADA':
        return 'Registrada';
      case 'EN_BUSQUEDA':
        return 'En Búsqueda';
      case 'ASIGNADA':
        return 'Asignada';
      case 'EN_ATENCION':
        return 'En Atención';
      case 'ATENDIDA':
        return 'Atendida';
      case 'CANCELADA':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'REGISTRADA':
      case 'EN_BUSQUEDA':
        return Colors.blue;
      case 'ASIGNADA':
      case 'EN_ATENCION':
        return Colors.orange;
      case 'ATENDIDA':
        return Colors.green;
      case 'CANCELADA':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 60) {
      return 'Hace ${diferencia.inMinutes} min';
    } else if (diferencia.inHours < 24) {
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} d';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Solicitudes de Emergencia'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtro de ordenamiento
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Ordenar por: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _ordenamiento,
                  items: const [
                    DropdownMenuItem(value: 'reciente', child: Text('Más Reciente')),
                    DropdownMenuItem(value: 'antiguo', child: Text('Más Antiguo')),
                  ],
                  onChanged: (valor) {
                    if (valor != null) {
                      _cambiarOrdenamiento(valor);
                    }
                  },
                ),
              ],
            ),
          ),
          // Listado de solicitudes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _solicitudes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay solicitudes registradas',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarSolicitudes,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _solicitudes.length,
                          itemBuilder: (context, index) {
                            final solicitud = _solicitudes[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetalleSolicitudScreen(
                                      solicitud: solicitud,
                                      onActualizar: _cargarSolicitudes,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Código y Estado
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            solicitud.codigoSolicitud,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getColorEstado(solicitud.estado),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _obtenerEstadoColor(solicitud.estado),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Vehículo
                                      Row(
                                        children: [
                                          Icon(Icons.directions_car, size: 18, color: Colors.grey[600]),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              solicitud.vehiculo,
                                              style: TextStyle(color: Colors.grey[600]),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Urgencia y Fecha
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.priority_high, size: 16, color: Colors.orange),
                                              const SizedBox(width: 4),
                                              Text(
                                                solicitud.nivelUrgencia,
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            _formatearFecha(solicitud.fechaCreacion),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
