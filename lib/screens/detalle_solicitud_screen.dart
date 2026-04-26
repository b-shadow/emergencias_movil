import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/solicitud.dart';
import '../models/postulacion.dart';
import '../services/solicitud_service.dart';
import '../services/postulacion_service.dart';
import 'editar_solicitud_screen.dart';
import '../widgets/theme_toggle_button.dart';

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
        content: const Text(
            '¿Estás seguro de que deseas cancelar esta solicitud de emergencia?'),
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
            child: const Text('Confirmar Cancelación',
                style: TextStyle(color: Colors.red)),
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
      final solicitud = await _solicitudService
          .obtenerDetalleSolicitud(_solicitudActual.idSolicitud);
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
      final postulaciones = await _postulacionService
          .obtenerPostulacionesSolicitud(_solicitudActual.idSolicitud);

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
        return const Color(0xFF1D9BF0);
      case 'ASIGNADA':
      case 'EN_ATENCION':
        return const Color(0xFFF59E0B);
      case 'ATENDIDA':
        return const Color(0xFF22C55E);
      case 'CANCELADA':
        return const Color(0xFFEF4444);
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
            child:
                const Text('Confirmar', style: TextStyle(color: Colors.blue)),
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
                  child: Text(
                      'Taller ${postulacion.nombreTaller} seleccionado exitosamente'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );

        await _recargarDetalle();
      }
    } catch (e) {
      if (mounted) {
        String mensaje = 'Error al seleccionar taller: $e';

        if (e.toString().contains('E1:')) {
          mensaje =
              'No hay talleres disponibles. Intenta ampliar la zona de búsqueda.';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final estadoColor = _getColorEstado(_solicitudActual.estado);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1117) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Detalle de Solicitud'),
        backgroundColor: const Color(0xFFFF5A5F),
        foregroundColor: Colors.white,
        actions: const [ThemeToggleButton()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B24) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: estadoColor.withOpacity(0.45), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.07),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Código de Solicitud',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withOpacity(0.62),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _solicitudActual.codigoSolicitud,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 34,
                                      color: cs.onSurface,
                                      letterSpacing: 0.4,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: estadoColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _solicitudActual.estado,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: cs.outlineVariant.withOpacity(0.45)),
                        const SizedBox(height: 14),
                        _buildInfoRow('Vehículo', _solicitudActual.vehiculo,
                            Icons.directions_car),
                        _buildInfoRow(
                          'Nivel de Urgencia',
                          _solicitudActual.nivelUrgencia,
                          Icons.priority_high,
                        ),
                        _buildInfoRow(
                          'Categoría',
                          _solicitudActual.categoria ?? 'No especificada',
                          Icons.warning_amber,
                        ),
                        _buildInfoRow(
                          'Radio de Búsqueda',
                          '${_solicitudActual.radioEstadio.toStringAsFixed(1)} km',
                          Icons.radar,
                        ),
                        if (_solicitudActual.latitud != null &&
                            _solicitudActual.longitud != null)
                          _buildMapWidget(_solicitudActual.latitud!,
                              _solicitudActual.longitud!)
                        else
                          _buildInfoRow(
                            'Ubicación',
                            'Sin coordenadas disponibles',
                            Icons.location_on,
                          ),
                        const SizedBox(height: 14),
                        _buildListaRow('Especialidades Necesarias',
                            _solicitudActual.especialidadesRequeridas),
                        const SizedBox(height: 12),
                        _buildListaRow('Servicios Necesarios',
                            _solicitudActual.serviciosRequeridos),
                        const SizedBox(height: 12),
                        _buildDescripcionRow(
                            'Descripción', _solicitudActual.descripcion),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_puedeEditar() || _puedeCancelar()) ...[
                    Text(
                      'Acciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_puedeEditar()) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
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
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar Solicitud'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_puedeCancelar())
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _cancelarSolicitud,
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancelar Solicitud'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                  ],
                  if (_solicitudActual.estado != 'CANCELADA' &&
                      _solicitudActual.estado != 'ATENDIDA') ...[
                    const SizedBox(height: 20),
                    Text(
                      'Talleres Postulados',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_cargandoPostulaciones)
                      const Center(child: CircularProgressIndicator())
                    else if (_postulaciones.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF12203A)
                              : const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF60A5FA).withOpacity(0.4)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xFF2563EB)),
                            const SizedBox(height: 8),
                            Text(
                              'Los talleres que respondan a tu solicitud aparecerán aquí',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.78)),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _postulaciones.length,
                        itemBuilder: (context, index) {
                          final postulacion = _postulaciones[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF181B24)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        postulacion.nombreTaller,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: cs.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDBEAFE),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '${postulacion.tiempoEstimadoMin} min',
                                        style: const TextStyle(
                                          color: Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (postulacion.mensajePropuesta != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    postulacion.mensajePropuesta!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSurface.withOpacity(0.72),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Postulado: ${postulacion.fechaPostulacion.toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withOpacity(0.58),
                                  ),
                                ),
                                if (_puedeSeleccionarTaller()) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _aceptarPostulacion(postulacion),
                                      icon: const Icon(Icons.check_circle,
                                          size: 18),
                                      label: const Text('Seleccionar Taller'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFFF5A5F), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withOpacity(0.62)),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaRow(String label, List<String> items) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              label.contains('Especialidades') ? Icons.business : Icons.build,
              color: const Color(0xFFFF5A5F),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style:
                  TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Sin seleccionar',
            style: TextStyle(
                color: cs.onSurface.withOpacity(0.52),
                fontStyle: FontStyle.italic),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    backgroundColor: isDark
                        ? const Color(0xFF173A60)
                        : const Color(0xFFE8F1FF),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFFB7D6FF)
                          : const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildDescripcionRow(String label, String? value) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: Color(0xFFFF5A5F), size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style:
                  TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1320) : const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
          ),
          child: Text(
            value ?? 'Sin descripción',
            style: TextStyle(
              fontSize: 13,
              color:
                  value != null ? cs.onSurface : cs.onSurface.withOpacity(0.52),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapWidget(double latitude, double longitude) {
    final cs = Theme.of(context).colorScheme;
    final LatLng location = LatLng(latitude, longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFFF5A5F), size: 20),
            const SizedBox(width: 12),
            Text(
              'Ubicación',
              style:
                  TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
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
                      radius: _solicitudActual.radioEstadio * 1000,
                      useRadiusInMeter: true,
                      color: Colors.blue.withOpacity(0.24),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: location,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF5A5F),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.location_on,
                            color: Colors.white, size: 24),
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
          style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.56)),
        ),
      ],
    );
  }
}
