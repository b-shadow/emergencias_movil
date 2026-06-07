import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'offline_sync_service.dart';

class TrackingService {
  static String get baseUrl => AuthService.baseUrl;

  final AuthService _authService = AuthService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  static const String _cacheOrdenes = 'cache_mis_ordenes';

  Future<List<dynamic>> obtenerMisOrdenes(
      {bool incluirHistorial = false}) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final uri = Uri.parse('$baseUrl/trabajadores/mis-ordenes').replace(
          queryParameters:
              incluirHistorial ? {'incluir_historial': 'true'} : null);
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        await _offlineSync.cacheJson(_cacheOrdenes, data);
        return data;
      }
      throw Exception('Error al obtener ordenes: ${resp.statusCode}');
    } catch (_) {
      final cached = await _offlineSync.getCachedJson(_cacheOrdenes);
      if (cached is List) {
        return cached;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> aceptarOrden(String idOrden) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/accept'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al aceptar orden: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> marcarLlegadaAuxilio(String idOrden) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse(
          '$baseUrl/trabajadores/ordenes-recojo/$idOrden/llegada-auxilio'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al marcar llegada al auxilio: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> obtenerTrackingOrden(String idOrden) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.get(
      Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/tracking'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception(
        'Error al obtener tracking de la orden: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> actualizarUbicacion(
      String idOrden, double lat, double lng) async {
    final payload = {'latitud': lat, 'longitud': lng, 'profile': 'foot'};
    try {
      final headers = await _authService.getAuthHeaders();
      final resp = await http.post(
        Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/ubicacion'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Error al actualizar ubicacion: ${resp.statusCode}');
    } catch (_) {
      await _offlineSync.enqueueOperation({
        'type': 'tracking_update',
        'id_orden': idOrden,
        'payload': payload,
      });
      return {
        'id_orden_recojo': idOrden,
        'estado_orden': 'PENDIENTE_SINCRONIZACION',
        'latitud_actual': lat,
        'longitud_actual': lng,
      };
    }
  }

  Future<Map<String, dynamic>> iniciarTrasladoTaller(String idOrden) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse(
          '$baseUrl/trabajadores/ordenes-recojo/$idOrden/iniciar-retorno'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al iniciar traslado al taller: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> marcarLlegadaTaller(String idOrden) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/llegada-taller'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al marcar llegada al taller: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> trackingPorSolicitud(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final resp = await http.get(
        Uri.parse('$baseUrl/trabajadores/solicitudes/$idSolicitud/tracking'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        await _offlineSync.cacheJson('tracking_solicitud_$idSolicitud', data);
        return data;
      }
      throw Exception('Tracking no disponible');
    } catch (_) {
      final cached =
          await _offlineSync.getCachedJson('tracking_solicitud_$idSolicitud');
      if (cached is Map) {
        return Map<String, dynamic>.from(cached);
      }
      rethrow;
    }
  }

  Future<void> syncPendingOperations() async {
    final pending = await _offlineSync.getPendingOperations();
    if (pending.isEmpty) return;
    final headers = await _authService.getAuthHeaders();
    final remains = <Map<String, dynamic>>[];
    for (final op in pending) {
      try {
        if (op['type'] == 'tracking_update') {
          final idOrden = op['id_orden'] as String;
          final payload = Map<String, dynamic>.from(op['payload'] as Map);
          final resp = await http.post(
            Uri.parse(
                '$baseUrl/trabajadores/ordenes-recojo/$idOrden/ubicacion'),
            headers: headers,
            body: jsonEncode(payload),
          );
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            remains.add(op);
          }
        }
      } catch (_) {
        remains.add(op);
      }
    }
    await _offlineSync.replacePendingOperations(remains);
  }
}
