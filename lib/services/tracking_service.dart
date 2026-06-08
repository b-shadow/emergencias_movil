import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'offline_sync_service.dart';

class TrackingService {
  static String get baseUrl => AuthService.baseUrl;

  final AuthService _authService = AuthService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  static const String _cacheOrdenes = 'cache_mis_ordenes';
  static const String _opTypeUpdate = 'tracking_update';
  static const String _opTypeAccept = 'tracking_accept';
  static const String _opTypeLlegadaAuxilio = 'tracking_llegada_auxilio';
  static const String _opTypeIniciarTraslado = 'tracking_iniciar_traslado';
  static const String _opTypeLlegadaTaller = 'tracking_llegada_taller';

  bool _shouldQueueOffline(Object error) {
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }

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
    try {
      final headers = await _authService.getAuthHeaders();
      final resp = await http.post(
        Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/accept'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Error al aceptar orden: ${resp.statusCode}');
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeAccept,
        'id_orden': idOrden,
      });
      return {
        'id_orden_recojo': idOrden,
        'estado_orden': 'ACEPTADA',
        'queued_offline': true,
        'message': 'Aceptación guardada para sincronizar cuando vuelva internet',
      };
    }
  }

  Future<Map<String, dynamic>> marcarLlegadaAuxilio(String idOrden) async {
    try {
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
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeLlegadaAuxilio,
        'id_orden': idOrden,
      });
      return {
        'id_orden_recojo': idOrden,
        'estado_orden': 'LLEGADA_AUXILIO',
        'queued_offline': true,
        'message': 'Llegada al auxilio guardada para sincronizar cuando vuelva internet',
      };
    }
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
        'type': _opTypeUpdate,
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
    try {
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
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeIniciarTraslado,
        'id_orden': idOrden,
      });
      return {
        'id_orden_recojo': idOrden,
        'estado_orden': 'EN_CAMINO_TALLER',
        'queued_offline': true,
        'message': 'Traslado al taller guardado para sincronizar cuando vuelva internet',
      };
    }
  }

  Future<Map<String, dynamic>> marcarLlegadaTaller(String idOrden) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final resp = await http.post(
        Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/llegada-taller'),
        headers: headers,
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      throw Exception('Error al marcar llegada al taller: ${resp.statusCode}');
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeLlegadaTaller,
        'id_orden': idOrden,
      });
      return {
        'id_orden_recojo': idOrden,
        'estado_orden': 'FINALIZADA',
        'queued_offline': true,
        'message': 'Llegada al taller guardada para sincronizar cuando vuelva internet',
      };
    }
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
        if (op['type'] == _opTypeUpdate) {
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
          continue;
        }

        if (op['type'] == _opTypeAccept) {
          final idOrden = (op['id_orden'] ?? '').toString();
          if (idOrden.isEmpty) continue;
          final resp = await http.post(
            Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/accept'),
            headers: headers,
          );
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            remains.add(op);
          }
          continue;
        }

        if (op['type'] == _opTypeLlegadaAuxilio) {
          final idOrden = (op['id_orden'] ?? '').toString();
          if (idOrden.isEmpty) continue;
          final resp = await http.post(
            Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/llegada-auxilio'),
            headers: headers,
          );
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            remains.add(op);
          }
          continue;
        }

        if (op['type'] == _opTypeIniciarTraslado) {
          final idOrden = (op['id_orden'] ?? '').toString();
          if (idOrden.isEmpty) continue;
          final resp = await http.post(
            Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/iniciar-retorno'),
            headers: headers,
          );
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            remains.add(op);
          }
          continue;
        }

        if (op['type'] == _opTypeLlegadaTaller) {
          final idOrden = (op['id_orden'] ?? '').toString();
          if (idOrden.isEmpty) continue;
          final resp = await http.post(
            Uri.parse('$baseUrl/trabajadores/ordenes-recojo/$idOrden/llegada-taller'),
            headers: headers,
          );
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            remains.add(op);
          }
          continue;
        }
        remains.add(op);
      } catch (_) {
        remains.add(op);
      }
    }
    await _offlineSync.replacePendingOperations(remains);
  }
}
