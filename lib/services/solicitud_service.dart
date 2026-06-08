import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/solicitud.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class SolicitudService {
  static String get baseUrl => AuthService.baseUrl;

  final AuthService _authService = AuthService();
  final OfflineSyncService _offlineSync = OfflineSyncService();

  static const String _cacheSolicitudes = 'cache_solicitudes';
  static const String _cacheSolicitudPrefix = 'cache_solicitud_';
  static const String _cacheHistorialPrefix = 'cache_solicitud_historial_';
  static const String _opTypeCancel = 'solicitud_cancel';
  static const String _opTypeUpdate = 'solicitud_update';

  bool _shouldQueueOffline(Object error) {
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }

  bool _isConnectivityError(Object error) {
    final text = error.toString();
    return _shouldQueueOffline(error) ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('timed out');
  }

  Future<List<Solicitud>> obtenerSolicitudes() async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/solicitudes_emergencia'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await _offlineSync.cacheJson(_cacheSolicitudes, data);
        return data
            .map((item) => Solicitud.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      }
      if (response.statusCode == 404) {
        return [];
      }
      throw Exception('Error al obtener solicitudes: ${response.statusCode}');
    } catch (e) {
      final cached = await _offlineSync.getCachedJson(_cacheSolicitudes);
      if (cached is List) {
        return cached
            .map((item) =>
                Solicitud.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_SOLICITUDES');
      }
      throw Exception('Error: $e');
    }
  }

  Future<Solicitud> obtenerDetalleSolicitud(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _offlineSync.cacheJson('$_cacheSolicitudPrefix$idSolicitud', data);
        return Solicitud.fromJson(data as Map<String, dynamic>);
      }
      if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      }
      if (response.statusCode == 404) {
        throw Exception('Solicitud no encontrada');
      }
      throw Exception('Error al obtener solicitud: ${response.statusCode}');
    } catch (e) {
      final cached =
          await _offlineSync.getCachedJson('$_cacheSolicitudPrefix$idSolicitud');
      if (cached is Map) {
        return Solicitud.fromJson(Map<String, dynamic>.from(cached));
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_DETALLE_SOLICITUD');
      }
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> cancelarSolicitud(String idSolicitud) async {
    const razon = 'Cancelada por el cliente desde la aplicación móvil';
    try {
      final headers = await _authService.getAuthHeaders();
      final body = {'razon': razon};

      final response = await http.post(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud/cancel'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      }
      if (response.statusCode == 404) {
        throw Exception('Solicitud no encontrada');
      }
      if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'No se puede cancelar esta solicitud');
      }
      throw Exception('Error al cancelar solicitud: ${response.statusCode}');
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeCancel,
        'id_solicitud': idSolicitud,
        'payload': {'razon': razon},
      });
      return {
        'queued_offline': true,
        'message':
            'Operación encolada para sincronización cuando vuelva internet',
      };
    }
  }

  Future<Map<String, dynamic>> actualizarSolicitud(
    String idSolicitud, {
    String? descripcion,
    String? nivelUrgencia,
    double? radioEstadio,
    String? categoria,
    List<String>? idEspecialidades,
    List<String>? idServicios,
  }) async {
    final Map<String, dynamic> body = {};
    if (descripcion != null) body['descripcion_texto'] = descripcion;
    if (nivelUrgencia != null) body['nivel_urgencia'] = nivelUrgencia;
    if (radioEstadio != null) body['radio_busqueda_km'] = radioEstadio;
    if (categoria != null) body['categoria_incidente'] = categoria;
    if (idEspecialidades != null) body['id_especialidades'] = idEspecialidades;
    if (idServicios != null) body['id_servicios'] = idServicios;

    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      }
      if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error al actualizar solicitud');
      }
      throw Exception('Error: ${response.statusCode}');
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeUpdate,
        'id_solicitud': idSolicitud,
        'payload': body,
      });
      return {
        'queued_offline': true,
        'message':
            'Actualización encolada para sincronización cuando vuelva internet',
      };
    }
  }

  Future<List<Map<String, dynamic>>> obtenerHistorialEstados(
      String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud/historial'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await _offlineSync.cacheJson('$_cacheHistorialPrefix$idSolicitud', data);
        return List<Map<String, dynamic>>.from(data);
      }
      if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      }
      throw Exception('Error al obtener historial: ${response.statusCode}');
    } catch (e) {
      final cached =
          await _offlineSync.getCachedJson('$_cacheHistorialPrefix$idSolicitud');
      if (cached is List) {
        return cached
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_HISTORIAL_SOLICITUD');
      }
      throw Exception('Error: $e');
    }
  }

  Future<void> syncPendingOperations() async {
    final pending = await _offlineSync.getPendingOperations();
    if (pending.isEmpty) return;

    final headers = await _authService.getAuthHeaders();
    final remains = <Map<String, dynamic>>[];

    for (final op in pending) {
      try {
        final type = (op['type'] ?? '').toString();
        if (type == _opTypeCancel) {
          final idSolicitud = (op['id_solicitud'] ?? '').toString();
          if (idSolicitud.isEmpty) continue;
          await http
              .post(
                Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud/cancel'),
                headers: headers,
                body: jsonEncode(op['payload'] ?? {}),
              )
              .timeout(const Duration(seconds: 10));
          continue;
        }

        if (type == _opTypeUpdate) {
          final idSolicitud = (op['id_solicitud'] ?? '').toString();
          if (idSolicitud.isEmpty) continue;
          await http
              .put(
                Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud'),
                headers: headers,
                body: jsonEncode(op['payload'] ?? {}),
              )
              .timeout(const Duration(seconds: 10));
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
