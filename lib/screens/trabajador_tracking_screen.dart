import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/tracking_service.dart';

class TrabajadorTrackingScreen extends StatefulWidget {
  const TrabajadorTrackingScreen({super.key});

  @override
  State<TrabajadorTrackingScreen> createState() => _TrabajadorTrackingScreenState();
}

class _TrabajadorTrackingScreenState extends State<TrabajadorTrackingScreen> {
  final TrackingService _trackingService = TrackingService();
  List<dynamic> _ordenes = [];
  Map<String, dynamic>? _actual;
  Timer? _timer;
  Timer? _wsPingTimer;
  Timer? _wsReconnectTimer;
  WebSocket? _ws;
  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _tickUbicacion());
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
    try {
      await _trackingService.syncPendingOperations();
      final rows = await _trackingService.obtenerMisOrdenes();
      setState(() {
        _ordenes = rows;
        if (_ordenes.isNotEmpty) {
          _selectedIndex = 0;
          _actual = _normalizeTracking(_ordenes[_selectedIndex] as Map<String, dynamic>);
          _connectWs();
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _aceptar() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.aceptarOrden(id);
    setState(() => _actual = _normalizeTracking(r));
    _connectWs();
  }

  Future<void> _marcarLlegadaAuxilio() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.marcarLlegadaAuxilio(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
    _connectWs();
  }

  Future<void> _iniciarRetorno() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.iniciarRetorno(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
  }

  Future<void> _marcarLlegadaTaller() async {
    if (_actual == null) return;
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.marcarLlegadaTaller(id);
    if (!mounted) return;
    setState(() => _actual = _normalizeTracking(r));
  }

  void _seleccionarOrden(int index) {
    if (index < 0 || index >= _ordenes.length) return;
    setState(() {
      _selectedIndex = index;
      _actual = _normalizeTracking(_ordenes[index] as Map<String, dynamic>);
    });
    _connectWs();
  }

  Future<void> _connectWs() async {
    if (_actual == null) return;
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
      _wsReconnectTimer?.cancel();
      _wsReconnectTimer = Timer(const Duration(seconds: 3), _connectWs);
    }, onError: (_) {
      _wsReconnectTimer?.cancel();
      _wsReconnectTimer = Timer(const Duration(seconds: 3), _connectWs);
    });
  }

  Future<void> _tickUbicacion() async {
    if (_actual == null) return;
    final granted = await Geolocator.requestPermission();
    if (granted == LocationPermission.denied || granted == LocationPermission.deniedForever) return;
    await _trackingService.syncPendingOperations();
    final pos = await Geolocator.getCurrentPosition();
    final id = _actual!['id_orden_recojo'].toString();
    final r = await _trackingService.actualizarUbicacion(id, pos.latitude, pos.longitude);
    if (!mounted) return;
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
    final rutaRecorridaGeo = _actual?['ruta_recorrida_geojson'] as Map<String, dynamic>?;
    final ruta = _toPolyline(rutaGeo);
    final rutaRecorrida = _toPolyline(rutaRecorridaGeo);
    final fechaAceptacion = DateTime.tryParse((_actual?['fecha_aceptacion'] ?? '').toString());
    final fechaLlegadaAuxilio = DateTime.tryParse((_actual?['fecha_llegada_auxilio'] ?? '').toString());
    final fechaInicioRegreso = DateTime.tryParse((_actual?['fecha_inicio_regreso'] ?? '').toString());
    final fechaLlegadaTaller = DateTime.tryParse((_actual?['fecha_llegada_taller'] ?? '').toString());
    final duracionTotal = (_actual?['duracion_total_segundos'] as num?)?.toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Asignaciones'),
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
              ? const Center(child: Text('No tienes ordenes activas'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_ordenes.length > 1)
                        SizedBox(
                          height: 46,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _ordenes.length,
                            itemBuilder: (context, index) {
                              final active = index == _selectedIndex;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: active,
                                  label: Text('Asignación ${index + 1}'),
                                  onSelected: (_) => _seleccionarOrden(index),
                                  avatar: Icon(
                                    Icons.assignment,
                                    size: 18,
                                    color: active ? Colors.white : Colors.blueGrey,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (_ordenes.length > 1) const SizedBox(height: 8),
                      Text(
                        'ID asignación: ${_actual!['id_asignacion']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('Estado: ${_actual!['estado_orden']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Distancia: ${((_actual!['distancia_metros'] ?? 0) as num).toStringAsFixed(0)} m'),
                      Text('ETA: ${(((_actual!['duracion_segundos'] ?? 0) as num) / 60).toStringAsFixed(0)} min'),
                      if (fechaAceptacion != null)
                        Text(
                          'Inicio: ${fechaAceptacion.toLocal()}${fechaLlegadaAuxilio != null ? ' | Auxilio: ${fechaLlegadaAuxilio.toLocal()}' : ''}${fechaInicioRegreso != null ? ' | Regreso: ${fechaInicioRegreso.toLocal()}' : ''}${fechaLlegadaTaller != null ? ' | Fin: ${fechaLlegadaTaller.toLocal()}' : ''}${duracionTotal != null ? ' | Total: ${(duracionTotal / 60).toStringAsFixed(0)} min' : ''}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      const SizedBox(height: 8),
                      if (_actual!['estado_orden'] == 'PENDIENTE_ACEPTACION')
                        ElevatedButton(onPressed: _aceptar, child: const Text('Iniciar recorrido')),
                      if (_actual!['estado_orden'] == 'ACEPTADA' || _actual!['estado_orden'] == 'EN_CAMINO_RECOJO')
                        ElevatedButton(onPressed: _marcarLlegadaAuxilio, child: const Text('Marcar llegada al auxilio')),
                      if (_actual!['estado_orden'] == 'LLEGADA_AUXILIO')
                        ElevatedButton(onPressed: _iniciarRetorno, child: const Text('Iniciar regreso')),
                      if (_actual!['estado_orden'] == 'EN_CAMINO_TALLER')
                        ElevatedButton(onPressed: _marcarLlegadaTaller, child: const Text('Marcar llegada al taller')),
                      const SizedBox(height: 8),
                      Expanded(
                        child: (lat == null || lng == null)
                            ? const Center(child: Text('Esperando ubicacion...'))
                            : FlutterMap(
                                options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 15),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.emergencias.vehicular/1.0.0',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(lat, lng),
                                        width: 42,
                                        height: 42,
                                        child: const Icon(Icons.delivery_dining, color: Colors.red, size: 36),
                                      ),
                                      if (latSolicitud != null && lngSolicitud != null)
                                        Marker(
                                          point: LatLng(latSolicitud, lngSolicitud),
                                          width: 42,
                                          height: 42,
                                          child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 34),
                                        ),
                                      if (latTaller != null && lngTaller != null)
                                        Marker(
                                          point: LatLng(latTaller, lngTaller),
                                          width: 42,
                                          height: 42,
                                          child: const Icon(Icons.home_work, color: Colors.blue, size: 34),
                                        ),
                                      if (latDestino != null && lngDestino != null)
                                        Marker(
                                          point: LatLng(latDestino, lngDestino),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(Icons.place, color: Colors.green, size: 34),
                                        ),
                                    ],
                                  ),
                                  if (rutaRecorrida.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(points: rutaRecorrida, strokeWidth: 4, color: Colors.grey),
                                      ],
                                    ),
                                  if (ruta.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(points: ruta, strokeWidth: 5, color: Colors.green),
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
