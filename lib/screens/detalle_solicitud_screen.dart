import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/solicitud.dart';
import '../models/postulacion.dart';
import '../services/solicitud_service.dart';
import '../services/postulacion_service.dart';
import '../services/tracking_service.dart';
import '../services/calificacion_service.dart';
import 'editar_solicitud_screen.dart';
import 'pagos_solicitud_screen.dart';
import '../widgets/theme_toggle_button.dart';

class DetalleSolicitudScreen extends StatefulWidget {
  final Solicitud solicitud;
  final VoidCallback onActualizar;

  const DetalleSolicitudScreen({
    super.key,
    required this.solicitud,
    required this.onActualizar,
  });

  @override
  State<DetalleSolicitudScreen> createState() => _DetalleSolicitudScreenState();
}

class _DetalleSolicitudScreenState extends State<DetalleSolicitudScreen> {
  final SolicitudService _solicitudService = SolicitudService();
  final PostulacionService _postulacionService = PostulacionService();
  final TrackingService _trackingService = TrackingService();
  final CalificacionService _calificacionService = CalificacionService();
  bool _isLoading = false;
  late Solicitud _solicitudActual;
  List<Postulacion> _postulaciones = [];
  final Map<String, Map<String, dynamic>> _cotizaciones = {};
  bool _cargandoPostulaciones = false;
  Map<String, dynamic>? _tracking;
  Timer? _trackingTimer;
  Timer? _wsPingTimer;
  Timer? _wsReconnectTimer;
  WebSocket? _trackingWs;
  bool _calificacionModalMostrado = false;
  int _estrellasCalificacion = 5;
  final TextEditingController _comentarioCalificacionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _solicitudActual = widget.solicitud;
    _cargarPostulaciones();
    _loadTracking();
    _trackingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _loadTracking());
    _connectTrackingWs();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _wsPingTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _trackingWs?.close();
    _comentarioCalificacionController.dispose();
    super.dispose();
  }

  Future<void> _connectTrackingWs() async {
    final idSolicitud = _solicitudActual.idSolicitud;
    final wsUrl = TrackingService.baseUrl.contains('localhost')
        ? 'ws://localhost:8000/api/v1/trabajadores/ws/solicitudes/$idSolicitud'
        : 'wss://emergencias-backend.onrender.com/api/v1/trabajadores/ws/solicitudes/$idSolicitud';
    try {
      _trackingWs = await WebSocket.connect(wsUrl);
      _wsPingTimer?.cancel();
      _wsPingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        try {
          _trackingWs?.add('ping');
        } catch (_) {}
      });
      _trackingWs!.listen((event) {
        try {
          final data = jsonDecode(event as String) as Map<String, dynamic>;
          if (!mounted) return;
          setState(() => _tracking = _normalizeTrackingPayload(data));
          _maybePedirCalificacion();
        } catch (_) {}
      }, onDone: () {
        _wsReconnectTimer?.cancel();
        _wsReconnectTimer = Timer(const Duration(seconds: 3), _connectTrackingWs);
      }, onError: (_) {
        _wsReconnectTimer?.cancel();
        _wsReconnectTimer = Timer(const Duration(seconds: 3), _connectTrackingWs);
      });
    } catch (_) {}
  }

  Future<void> _loadTracking() async {
    try {
      final t = await _trackingService.trackingPorSolicitud(_solicitudActual.idSolicitud);
      if (!mounted) return;
      setState(() => _tracking = _normalizeTrackingPayload(t));
      _maybePedirCalificacion();
    } catch (_) {}
  }

  Future<void> _maybePedirCalificacion() async {
    if (!mounted || _calificacionModalMostrado || _tracking == null) return;
    final estado = (_tracking!['estado_orden'] ?? '').toString();
    final idAsignacion = (_tracking!['id_asignacion'] ?? '').toString();
    if (estado != 'FINALIZADA' && estado != 'ATENDIDA') return;
    if (idAsignacion.isEmpty) return;

    try {
      final existente = await _calificacionService.obtenerCalificacion(idAsignacion);
      if (!mounted || existente != null) return;
      _calificacionModalMostrado = true;
      await _mostrarModalCalificacion(idAsignacion);
    } catch (_) {}
  }

  Future<void> _mostrarModalCalificacion(String idAsignacion) async {
    _estrellasCalificacion = 5;
    _comentarioCalificacionController.clear();
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Text('Calificar atención'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Cómo quedó tu vehículo?'),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      final selected = index < _estrellasCalificacion;
                      return IconButton(
                        onPressed: () => setStateModal(() => _estrellasCalificacion = index + 1),
                        icon: Icon(
                          selected ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: _comentarioCalificacionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentario',
                      hintText: 'Cuéntanos cómo fue la atención',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await _calificacionService.calificarAtencion(
                        idAsignacion,
                        estrellas: _estrellasCalificacion,
                        comentario: _comentarioCalificacionController.text.trim().isEmpty
                            ? null
                            : _comentarioCalificacionController.text.trim(),
                      );
                      if (!mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Calificación registrada')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );
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
      _maybePedirCalificacion();
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
        for (final p in postulaciones) {
          _cargarCotizacion(p.idPostulacion);
        }
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

  Future<void> _cargarCotizacion(String idPostulacion) async {
    try {
      final cotizacion = await _postulacionService.obtenerCotizacion(idPostulacion);
      if (!mounted) return;
      setState(() {
        _cotizaciones[idPostulacion] = cotizacion;
      });
    } catch (_) {}
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
    final cot = _cotizaciones[postulacion.idPostulacion];
    if (cot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este taller aún no envió su cotización')),
      );
      return;
    }
    final confirm = await _mostrarDialogoCotizacion(postulacion, cot);
    if (confirm != true) return;
    if (!mounted) return;

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
      await _postulacionService.decidirCotizacion(postulacion.idPostulacion, true);

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

  Future<bool?> _mostrarDialogoCotizacion(Postulacion postulacion, Map<String, dynamic> cotizacion) {
    final servicios = (cotizacion['servicios'] as List<dynamic>? ?? const []);
    final total = (cotizacion['precio_total_estimado'] as num?)?.toDouble() ?? 0;
    final eta = cotizacion['tiempo_estimado_llegada_min'] ?? postulacion.tiempoEstimadoMin;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cotización de ${postulacion.nombreTaller}'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tiempo estimado de llegada: $eta min'),
                const SizedBox(height: 8),
                const Text('Detalle de servicios:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...servicios.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '- ${s['nombre_servicio'] ?? 'Servicio'}: Bs ${(s['precio_servicio'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                      ),
                    )),
                const SizedBox(height: 8),
                Text('Cargo por cancelación (10%): Bs ${(total * 0.1).toStringAsFixed(2)}'),
                Text('Total estimado: Bs ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context, false);
              try {
                await _postulacionService.decidirCotizacion(postulacion.idPostulacion, false);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Cotización rechazada')),
                );
              } catch (_) {}
            },
            child: const Text('Rechazar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar y continuar'),
          ),
        ],
      ),
    );
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
                          color: estadoColor.withValues(alpha: 0.45), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
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
                                      color: cs.onSurface.withValues(alpha: 0.62),
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
                        Divider(color: cs.outlineVariant.withValues(alpha: 0.45)),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PagosSolicitudScreen(
                              idSolicitud: _solicitudActual.idSolicitud,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payments),
                      label: const Text('Gestionar Pagos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
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
                              color: const Color(0xFF60A5FA).withValues(alpha: 0.4)),
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
                                  color: cs.onSurface.withValues(alpha: 0.78)),
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
                                color: cs.outlineVariant.withValues(alpha: 0.35),
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
                                      color: cs.onSurface.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Postulado: ${postulacion.fechaPostulacion.toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.58),
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
                  if (_tracking != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Tracking en tiempo real',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estado: ${_tracking!['estado_orden']} | ETA: ${(((_tracking!['duracion_segundos'] ?? 0) as num) / 60).toStringAsFixed(0)} min',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.72)),
                    ),
                    if (_tracking!['duracion_total_segundos'] != null)
                      Text(
                        'Tiempo total: ${(((_tracking!['duracion_total_segundos'] ?? 0) as num) / 60).toStringAsFixed(0)} min',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.68)),
                      ),
                    if (_tracking!['latitud_actual'] != null && _tracking!['longitud_actual'] != null)
                      _buildTrackingMapWidget(_tracking!),
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
                      fontSize: 12, color: cs.onSurface.withValues(alpha: 0.62)),
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
                  TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'Sin seleccionar',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.52),
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
                  TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
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
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Text(
            value ?? 'Sin descripción',
            style: TextStyle(
              fontSize: 13,
              color:
                  value != null ? cs.onSurface : cs.onSurface.withValues(alpha: 0.52),
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
                  TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
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
                      color: Colors.blue.withValues(alpha: 0.24),
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
          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.56)),
        ),
      ],
    );
  }

  Widget _buildTrackingMapWidget(Map<String, dynamic> tracking) {
    final lat = (tracking['latitud_actual'] as num).toDouble();
    final lng = (tracking['longitud_actual'] as num).toDouble();
    final latDestino = (tracking['latitud_destino'] as num?)?.toDouble();
    final lngDestino = (tracking['longitud_destino'] as num?)?.toDouble();
    final latSolicitud = (tracking['latitud_solicitud'] as num?)?.toDouble();
    final lngSolicitud = (tracking['longitud_solicitud'] as num?)?.toDouble();
    final latTaller = (tracking['latitud_taller'] as num?)?.toDouble();
    final lngTaller = (tracking['longitud_taller'] as num?)?.toDouble();
    final ruta = _geoLineToLatLng(tracking['ruta_geojson']);
    final rutaRecorrida = _geoLineToLatLng(tracking['ruta_recorrida_geojson']);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 250,
        child: FlutterMap(
          options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15.0),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.emergencias.vehicular/1.0.0',
            ),
            if (rutaRecorrida.isNotEmpty)
              PolylineLayer(polylines: [Polyline(points: rutaRecorrida, strokeWidth: 4, color: Colors.grey)]),
            if (ruta.isNotEmpty)
              PolylineLayer(polylines: [Polyline(points: ruta, strokeWidth: 5, color: Colors.green)]),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(lat, lng),
                  width: 44,
                  height: 44,
                  child: const Icon(Icons.delivery_dining, color: Colors.red, size: 34),
                ),
                if (latSolicitud != null && lngSolicitud != null)
                  Marker(
                    point: LatLng(latSolicitud, lngSolicitud),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 34),
                  ),
                if (latTaller != null && lngTaller != null)
                  Marker(
                    point: LatLng(latTaller, lngTaller),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.home_work, color: Colors.blue, size: 34),
                  ),
                if (latDestino != null && lngDestino != null)
                  Marker(
                    point: LatLng(latDestino, lngDestino),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.place, color: Colors.green, size: 34),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _geoLineToLatLng(dynamic geo) {
    if (geo is! Map<String, dynamic>) return const [];
    if (geo['type'] != 'LineString') return const [];
    final coords = geo['coordinates'];
    if (coords is! List) return const [];
    return coords
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  Map<String, dynamic> _normalizeTrackingPayload(Map<String, dynamic> raw) {
    final out = Map<String, dynamic>.from(raw);
    for (final key in ['ruta_geojson', 'ruta_recorrida_geojson']) {
      final value = out[key];
      if (value is String && value.isNotEmpty) {
        try {
          out[key] = jsonDecode(value);
        } catch (_) {}
      }
    }
    return out;
  }
}


