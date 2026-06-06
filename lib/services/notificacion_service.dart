import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notificacion.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class NotificacionService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  static const String _cacheNotificaciones = 'cache_notificaciones_mias';
  static const String _opTypeMarkRead = 'notificacion_marcar_leida';
  static const String _opTypeMarkAllRead = 'notificacion_marcar_todas';

  // Obtener mis notificaciones
  Future<NotificacionResponse> obtenerMisNotificaciones({
    int limit = 10,
    int offset = 0,
    String? estadoLectura,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();

      String url = '$baseUrl/notificaciones/mias?limit=$limit&offset=$offset';
      
      if (estadoLectura != null && estadoLectura.isNotEmpty) {
        url += '&estado_lectura=$estadoLectura';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _offlineSync.cacheJson(_cacheNotificaciones, data);
        return NotificacionResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        return NotificacionResponse(total: 0, noLeidas: 0, items: []);
      } else {
        throw Exception('Error al obtener notificaciones: ${response.statusCode}');
      }
    } catch (e) {
      final cached = await _offlineSync.getCachedJson(_cacheNotificaciones);
      if (cached is Map<String, dynamic>) {
        return NotificacionResponse.fromJson(cached);
      }
      throw Exception('Error: $e');
    }
  }

  // Obtener detalle de una notificación
  Future<Notificacion> obtenerDetalleNotificacion(String idNotificacion) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/notificaciones/mias/$idNotificacion'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Notificacion.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Notificación no encontrada');
      } else {
        throw Exception('Error al obtener notificación: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Marcar notificación como leída
  Future<Map<String, dynamic>> marcarComoLeida(String idNotificacion) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.patch(
        Uri.parse('$baseUrl/notificaciones/mias/$idNotificacion/leer'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Notificación no encontrada');
      } else {
        throw Exception('Error al marcar notificación: ${response.statusCode}');
      }
    } catch (e) {
      await _offlineSync.enqueueOperation({
        'type': _opTypeMarkRead,
        'id_notificacion': idNotificacion,
      });
      return {
        'queued_offline': true,
        'message': 'Marcado encolado para sincronizar cuando vuelva internet',
      };
    }
  }

  // Marcar todas como leídas
  Future<Map<String, dynamic>> marcarTodasComoLeidas() async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.patch(
        Uri.parse('$baseUrl/notificaciones/mias/mark-all-read'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else {
        throw Exception('Error al marcar notificaciones: ${response.statusCode}');
      }
    } catch (e) {
      await _offlineSync.enqueueOperation({
        'type': _opTypeMarkAllRead,
      });
      return {
        'queued_offline': true,
        'message': 'Marcado masivo encolado para sincronizar cuando vuelva internet',
      };
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
        if (type == _opTypeMarkRead) {
          final id = (op['id_notificacion'] ?? '').toString();
          if (id.isEmpty) continue;
          await http.patch(
            Uri.parse('$baseUrl/notificaciones/mias/$id/leer'),
            headers: headers,
          ).timeout(const Duration(seconds: 10));
          continue;
        }
        if (type == _opTypeMarkAllRead) {
          await http.patch(
            Uri.parse('$baseUrl/notificaciones/mias/mark-all-read'),
            headers: headers,
          ).timeout(const Duration(seconds: 10));
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

