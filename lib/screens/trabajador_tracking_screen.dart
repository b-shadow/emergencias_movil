import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/tracking_service.dart';

class TrabajadorTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> ordenInicial;

  const TrabajadorTrackingScreen({
    super.key,
    required this.ordenInicial,
  });

  @override
  State<TrabajadorTrackingScreen> createState() =>
      _TrabajadorTrackingScreenState();
}

class _TrabajadorTrackingScreenState extends State<TrabajadorTrackingScreen> {
  final TrackingService _trackingService = TrackingService();
  Map<String, dynamic>? _actual;
  Timer? _timer;
  Timer? _wsPingTimer;
  Timer? _wsReconnectTimer;
  WebSocket? _ws;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _actual = _normalizeTracking(widget.ordenInicial);
    _cargar();
    _timer =
        Timer.periodic(const Duration(seconds: 8), (_) => _tickUbicacion());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsPingTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _ws?.close();
    super.dispose();
  }

  Future<void> _cargar() async {
    final idOrden = _actual?['id_orden_recojo']?.toString();
    if (idOrden == null || idOrden.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    try {
      await _trackingService.syncPendingOperations();
      final row = await _trackingService.obtenerTrackingOrden(idOrden);
      if (!mounted) return;
      setState(() {
        _actual = _normalizeTracking(row);
        _loading = false;
      });
      _connectWsIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _aceptar() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.aceptarOrden(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
    _connectWsIfNeeded();
  }

  Future<void> _marcarLlegadaAuxilio() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.marcarLlegadaAuxilio(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
    _connectWsIfNeeded();
  }

  Future<void> _iniciarTrasladoTaller() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.iniciarTrasladoTaller(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
    _connectWsIfNeeded();
  }

  Future<void> _marcarLlegadaTaller() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.marcarLlegadaTaller(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
    await _ws?.close();
  }

  bool _esOrdenActiva(String? estado) {
    return estado == 'PENDIENTE_ACEPTACION' ||
        estado == 'ACEPTADA' ||
        estado == 'EN_CAMINO_RECOJO' ||
        estado == 'LLEGADA_AUXILIO' ||
        estado == 'EN_CAMINO_TALLER';
  }

  bool _permiteUbicacion(String? estado) {
    return estado == 'PENDIENTE_ACEPTACION' ||
        estado == 'ACEPTADA' ||
        estado == 'EN_CAMINO_RECOJO' ||
        estado == 'LLEGADA_AUXILIO' ||
        estado == 'EN_CAMINO_TALLER';
  }

  Future<void> _connectWsIfNeeded() async {
    final estado = _actual?['estado_orden']?.toString();
    if (!_esOrdenActiva(estado) || _actual == null) {
      await _ws?.close();
      _ws = null;
      return;
    }

    await _ws?.close();
    final id = _actual!['id_orden_recojo'].toString();
    final wsUrl = TrackingService.baseUrl.contains('localhost')
        ? 'ws://localhost:8000/api/v1/trabajadores/ws/ordenes-recojo/$id'
        : 'wss://emergencias-backend.onrender.com/api/v1/trabajadores/ws/ordenes-recojo/$id';
    _ws = await WebSocket.connect(wsUrl);
    _wsPingTimer?.cancel();
    _wsPingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      try {
        _ws?.add('ping');
      } catch (_) {}
    });
    _ws!.listen((event) {
      try {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() => _actual = _normalizeTracking(data));
      } catch (_) {}
    }, onDone: () {
      if (!_esOrdenActiva(_actual?['estado_orden']?.toString())) {
        return;
      }
      _wsReconnectTimer?.cancel();
      _wsReconnectTimer = Timer(const Duration(seconds: 3), _connectWsIfNeeded);
    }, onError: (_) {
      if (!_esOrdenActiva(_actual?['estado_orden']?.toString())) {
        return;
      }
      _wsReconnectTimer?.cancel();
      _wsReconnectTimer = Timer(const Duration(seconds: 3), _connectWsIfNeeded);
    });
  }

  Future<void> _tickUbicacion() async {
    final estado = _actual?['estado_orden']?.toString();
    if (_actual == null || !_permiteUbicacion(estado)) {
      return;
    }
    final granted = await Geolocator.requestPermission();
    if (granted == LocationPermission.denied ||
        granted == LocationPermission.deniedForever) {
      return;
    }
    await _trackingService.syncPendingOperations();
    final pos = await Geolocator.getCurrentPosition();
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.actualizarUbicacion(
        id, pos.latitude, pos.longitude);
    if (!mounted) {
      return;
    }
    setState(() => _actual = _normalizeTracking(r));
  }

  @override
  Widget build(BuildContext context) {
    final lat = (_actual?['latitud_actual'] as num?)?.toDouble();
    final lng = (_actual?['longitud_actual'] as num?)?.toDouble();
    final latDestino = (_actual?['latitud_destino'] as num?)?.toDouble();
    final lngDestino = (_actual?['longitud_destino'] as num?)?.toDouble();
    final latSolicitud = (_actual?['latitud_solicitud'] as num?)?.toDouble();
    final lngSolicitud = (_actual?['longitud_solicitud'] as num?)?.toDouble();
    final latTaller = (_actual?['latitud_taller'] as num?)?.toDouble();
    final lngTaller = (_actual?['longitud_taller'] as num?)?.toDouble();
    final rutaGeo = _actual?['ruta_geojson'] as Map<String, dynamic>?;
    final rutaRecorridaGeo =
        _actual?['ruta_recorrida_geojson'] as Map<String, dynamic>?;
    final ruta = _toPolyline(rutaGeo);
    final rutaRecorrida = _toPolyline(rutaRecorridaGeo);
    final fechaAceptacion =
        DateTime.tryParse((_actual?['fecha_aceptacion'] ?? '').toString());
    final fechaLlegadaAuxilio =
        DateTime.tryParse((_actual?['fecha_llegada_auxilio'] ?? '').toString());
    final fechaInicioRegreso =
        DateTime.tryParse((_actual?['fecha_inicio_regreso'] ?? '').toString());
    final fechaLlegadaTaller =
        DateTime.tryParse((_actual?['fecha_llegada_taller'] ?? '').toString());
    final duracionTotal =
        (_actual?['duracion_total_segundos'] as num?)?.toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _actual?['codigo_solicitud']?.toString() ?? 'Detalle de orden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _actual == null
              ? const Center(child: Text('No se pudo cargar la orden'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _actual!['cliente_nombre']?.toString().isNotEmpty ==
                                true
                            ? 'Cliente: ${_actual!['cliente_nombre']}'
                            : 'ID asignación: ${_actual!['id_asignacion']}',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('Estado: ${_actual!['estado_orden']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          'Distancia: ${((_actual!['distancia_metros'] ?? 0) as num).toStringAsFixed(0)} m'),
                      Text(
                          'ETA: ${(((_actual!['duracion_segundos'] ?? 0) as num) / 60).toStringAsFixed(0)} min'),
                      if (fechaAceptacion != null)
                        Text(
                          'Inicio: ${fechaAceptacion.toLocal()}${fechaLlegadaAuxilio != null ? ' | Auxilio: ${fechaLlegadaAuxilio.toLocal()}' : ''}${fechaInicioRegreso != null ? ' | Traslado: ${fechaInicioRegreso.toLocal()}' : ''}${fechaLlegadaTaller != null ? ' | Taller: ${fechaLlegadaTaller.toLocal()}' : ''}${duracionTotal != null ? ' | Total: ${(duracionTotal / 60).toStringAsFixed(0)} min' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      const SizedBox(height: 8),
                      if (_actual!['estado_orden'] == 'PENDIENTE_ACEPTACION')
                        ElevatedButton(
                            onPressed: _aceptar,
                            child: const Text('Iniciar camino al auxilio')),
                      if (_actual!['estado_orden'] == 'ACEPTADA' ||
                          _actual!['estado_orden'] == 'EN_CAMINO_RECOJO')
                        ElevatedButton(
                            onPressed: _marcarLlegadaAuxilio,
                            child: const Text('Marcar llegada al auxilio')),
                      if (_actual!['estado_orden'] == 'LLEGADA_AUXILIO')
                        ElevatedButton(
                            onPressed: _iniciarTrasladoTaller,
                            child: const Text('Iniciar traslado al taller')),
                      if (_actual!['estado_orden'] == 'EN_CAMINO_TALLER')
                        ElevatedButton(
                            onPressed: _marcarLlegadaTaller,
                            child: const Text('Marcar llegada al taller')),
                      const SizedBox(height: 8),
                      Expanded(
                        child: (lat == null || lng == null)
                            ? const Center(
                                child: Text('Esperando ubicación...'))
                            : FlutterMap(
                                options: MapOptions(
                                    initialCenter: LatLng(lat, lng),
                                    initialZoom: 15),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.emergencias.vehicular/1.0.0',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 42,
                                        height: 42,
                                        child: const Icon(Icons.delivery_dining,
                                            color: Colors.red, size: 36),
                                      ),
                                      if (latSolicitud != null &&
                                          lngSolicitud != null)
                                        Marker(
                                          point: LatLng(
                                              latSolicitud, lngSolicitud),
                                          width: 42,
                                          height: 42,
                                          child: const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange,
                                              size: 34),
                                        ),
                                      if (latTaller != null &&
                                          lngTaller != null)
                                        Marker(
                                          point: LatLng(latTaller, lngTaller),
                                          width: 42,
                                          height: 42,
                                          child: const Icon(Icons.home_work,
                                              color: Colors.blue, size: 34),
                                        ),
                                      if (latDestino != null &&
                                          lngDestino != null)
                                        Marker(
                                          point: LatLng(latDestino, lngDestino),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(Icons.place,
                                              color: Colors.green, size: 34),
                                        ),
                                    ],
                                  ),
                                  if (rutaRecorrida.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                            points: rutaRecorrida,
                                            strokeWidth: 4,
                                            color: Colors.grey),
                                      ],
                                    ),
                                  if (ruta.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                            points: ruta,
                                            strokeWidth: 5,
                                            color: Colors.green),
                                      ],
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  List<LatLng> _toPolyline(Map<String, dynamic>? geo) {
    if (geo == null) return const [];
    if (geo['type'] != 'LineString') return const [];
    final coords = geo['coordinates'];
    if (coords is! List) return const [];
    return coords
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  Map<String, dynamic> _normalizeTracking(Map<String, dynamic> raw) {
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
