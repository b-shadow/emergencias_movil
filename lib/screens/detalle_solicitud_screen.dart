import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/solicitud.dart';
import '../models/postulacion.dart';
import '../services/solicitud_service.dart';
import '../services/postulacion_service.dart';
import 'editar_solicitud_screen.dart';

class DetalleSolicitudScreen extends StatefulWidget {
  final Solicitud solicitud;
  final VoidCallback onActualizar;

  const DetalleSolicitudScreen({
    Key? key,
    required this.solicitud,
    required this.onActualizar,
  }) : super(key: key);

  @override
  State<DetalleSolicitudScreen> createState() => _DetalleSolicitudScreenState();
}

class _DetalleSolicitudScreenState extends State<DetalleSolicitudScreen> {
  final SolicitudService _solicitudService = SolicitudService();
  final PostulacionService _postulacionService = PostulacionService();
  bool _isLoading = false;
  late Solicitud _solicitudActual;
  List<Postulacion> _postulaciones = [];
  bool _cargandoPostulaciones = false;

  @override
  void initState() {
    super.initState();
    _solicitudActual = widget.solicitud;
    _cargarPostulaciones();
  }

  Future<void> _cancelarSolicitud() async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancelar Solicitud'),
        content: const Text('¿Estás seguro de que deseas cancelar esta solicitud de emergencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmarCancelacion();
            },
            child: const Text('Confirmar Cancelación', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCancelacion() async {
    try {
      setState(() => _isLoading = true);
      await _solicitudService.cancelarSolicitud(_solicitudActual.idSolicitud);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Solicitud cancelada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onActualizar();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recargarDetalle() async {
    try {
      final solicitud = await _solicitudService.obtenerDetalleSolicitud(_solicitudActual.idSolicitud);
      setState(() => _solicitudActual = solicitud);
      await _cargarPostulaciones();
      widget.onActualizar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recargar: $e')),
        );
      }
    }
  }

  Future<void> _cargarPostulaciones() async {
    if (!mounted) return;
    
    try {
      setState(() => _cargandoPostulaciones = true);
      final postulaciones = await _postulacionService.obtenerPostulacionesSolicitud(_solicitudActual.idSolicitud);
      
      if (mounted) {
        setState(() {
          _postulaciones = postulaciones;
          _cargandoPostulaciones = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoPostulaciones = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar postulaciones: $e')),
        );
      }
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

  bool _puedeCancelar() {
    return _solicitudActual.estado != 'CANCELADA' &&
        _solicitudActual.estado != 'ATENDIDA';
  }

  bool _puedeEditar() {
    return _solicitudActual.estado == 'REGISTRADA' ||
        _solicitudActual.estado == 'EN_BUSQUEDA';
  }

  bool _puedeSeleccionarTaller() {
    return _solicitudActual.estado != 'CANCELADA' &&
        _solicitudActual.estado != 'ATENDIDA' &&
        _solicitudActual.estado != 'TALLER_SELECCIONADO';
  }

  Future<void> _aceptarPostulacion(Postulacion postulacion) async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirmar Selección'),
        content: Text(
          '¿Deseas seleccionar a ${postulacion.nombreTaller} para atender tu emergencia?\n\n'
          'Tiempo estimado: ${postulacion.tiempoEstimadoMin} minutos',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmarAceptacion(postulacion);
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarAceptacion(Postulacion postulacion) async {
    try {
      setState(() => _isLoading = true);
      
      await _postulacionService.aceptarPostulacion(postulacion.idPostulacion);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Taller ${postulacion.nombreTaller} seleccionado exitosamente'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Recargar solicitud para actualizar estado
        await _recargarDetalle();
      }
    } catch (e) {
      if (mounted) {
        String mensaje = 'Error al seleccionar taller: $e';
        
        // Manejo específico de errores
        if (e.toString().contains('E1:')) {
          mensaje = 'No hay talleres disponibles. Intenta ampliar la zona de búsqueda.';
        } else if (e.toString().contains('E2:')) {
          mensaje = 'La solicitud ya cuenta con un taller asignado.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Solicitud'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card principal con información
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Código y Estado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Código de Solicitud',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _solicitudActual.codigoSolicitud,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _getColorEstado(_solicitudActual.estado),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _solicitudActual.estado,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Vehículo
                          _buildInfoRow('Vehículo', _solicitudActual.vehiculo, Icons.directions_car),
                          const SizedBox(height: 12),
                          // Urgencia
                          _buildInfoRow('Nivel de Urgencia', _solicitudActual.nivelUrgencia, Icons.priority_high),
                          const SizedBox(height: 12),
                          // Categoría
                          _buildInfoRow('Categoría', _solicitudActual.categoria ?? 'No especificada', Icons.warning_amber),
                          const SizedBox(height: 12),
                          // Radio de búsqueda
                          _buildInfoRow('Radio de Búsqueda', '${_solicitudActual.radioEstadio.toStringAsFixed(1)} km', Icons.adjust),
                          const SizedBox(height: 12),
                          // Ubicación con Mapa
                          if (_solicitudActual.latitud != null && _solicitudActual.longitud != null)
                            _buildMapWidget(_solicitudActual.latitud!, _solicitudActual.longitud!)
                          else
                            _buildInfoRow(
                              'Ubicación',
                              'Sin coordenadas disponibles',
                              Icons.location_on,
                            ),
                          const SizedBox(height: 12),
                          // Especialidades
                          _buildListaRow('Especialidades Necesarias', _solicitudActual.especialidadesRequeridas),
                          const SizedBox(height: 12),
                          // Servicios
                          _buildListaRow('Servicios Necesarios', _solicitudActual.serviciosRequeridos),
                          const SizedBox(height: 12),
                          // Descripción
                          _buildDescripcionRow('Descripción', _solicitudActual.descripcion),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sección de acciones según estado
                  if (_puedeEditar() || _puedeCancelar()) ...[
                    const Text(
                      'Acciones',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (_puedeEditar()) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditarSolicitudScreen(
                                  solicitud: _solicitudActual,
                                  onActualizar: _recargarDetalle,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Editar Solicitud'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_puedeCancelar())
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cancelarSolicitud,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel),
                              SizedBox(width: 8),
                              Text('Cancelar Solicitud'),
                            ],
                          ),
                        ),
                      ),
                  ],
                  // Mostrar talleres postulados si existen y solicitud está activa
                  if (_solicitudActual.estado != 'CANCELADA' &&
                      _solicitudActual.estado != 'ATENDIDA') ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Talleres Postulados',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (_cargandoPostulaciones)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else if (_postulaciones.isEmpty)
                      const Card(
                        color: Colors.blue,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.info, color: Colors.white),
                              SizedBox(height: 8),
                              Text(
                                'Los talleres que respondan a tu solicitud aparecerán aquí',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _postulaciones.length,
                        itemBuilder: (context, index) {
                          final postulacion = _postulaciones[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          postulacion.nombreTaller,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${postulacion.tiempoEstimadoMin} min',
                                          style: TextStyle(
                                            color: Colors.blue.shade900,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (postulacion.mensajePropuesta != null)
                                    Text(
                                      postulacion.mensajePropuesta!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Postulado: ${postulacion.fechaPostulacion.toString().split('.')[0]}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (_puedeSeleccionarTaller()) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _aceptarPostulacion(postulacion),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle, size: 18),
                                            SizedBox(width: 8),
                                            Text('Seleccionar Taller'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListaRow(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              label.contains('Especialidades') ? Icons.business : Icons.build,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text(
            'Sin seleccionar',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: Colors.blue[100],
                    labelStyle: const TextStyle(fontSize: 12),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildDescripcionRow(String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value ?? 'Sin descripción',
            style: TextStyle(
              fontSize: 13,
              color: value != null ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapWidget(double latitude, double longitude) {
    final LatLng location = LatLng(latitude, longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            const Text(
              'Ubicación',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 250,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: location,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.emergencias.vehicular/1.0.0',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: location,
                      radius: _solicitudActual.radioEstadio * 1000, // Radio en metros
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 40,
                      height: 40,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Lat: ${latitude.toStringAsFixed(4)} | Lng: ${longitude.toStringAsFixed(4)}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
