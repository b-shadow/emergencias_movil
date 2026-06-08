import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'offline_sync_service.dart';

class CalificacionService {
  static String get baseUrl => AuthService.baseUrl;

  final AuthService _authService = AuthService();
  final OfflineSyncService _offlineSync = OfflineSyncService();

  static const String _opTypeCreate = 'calificacion_create';

  bool _shouldQueueOffline(Object error) {
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }

  Future<Map<String, dynamic>?> obtenerCalificacion(String idAsignacion) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.get(
      Uri.parse('$baseUrl/asignaciones/$idAsignacion/calificacion'),
      headers: headers,
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      if (body == null) return null;
      return Map<String, dynamic>.from(body as Map);
    }
    if (resp.statusCode == 404) return null;
    throw Exception('Error al consultar calificación: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> calificarAtencion(
    String idAsignacion, {
    required int estrellas,
    String? comentario,
    bool confirmoEstado = true,
  }) async {
    final payload = {
      'estrellas': estrellas,
      'comentario': comentario,
      'confirmo_estado': confirmoEstado,
    };

    try {
      final headers = await _authService.getAuthHeaders();
      final resp = await http
          .post(
            Uri.parse('$baseUrl/asignaciones/$idAsignacion/calificacion'),
            headers: headers,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 201) {
        return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
      }
      final error = jsonDecode(resp.body);
      throw Exception(error['detail'] ?? 'Error al registrar calificación');
    } catch (e) {
      if (!_shouldQueueOffline(e)) rethrow;
      await _offlineSync.enqueueOperation({
        'type': _opTypeCreate,
        'id_asignacion': idAsignacion,
        'payload': payload,
      });
      return {
        'queued_offline': true,
        'message': 'Calificación guardada para sincronizar cuando vuelva internet',
      };
    }
  }

  Future<bool> hasPendingCalificacion(String idAsignacion) async {
    final pending = await _offlineSync.getPendingOperations();
    return pending.any(
      (op) =>
          (op['type'] ?? '').toString() == _opTypeCreate &&
          (op['id_asignacion'] ?? '').toString() == idAsignacion,
    );
  }

  Future<void> syncPendingOperations() async {
    final pending = await _offlineSync.getPendingOperations();
    if (pending.isEmpty) return;
    final headers = await _authService.getAuthHeaders();
    final remains = <Map<String, dynamic>>[];

    for (final op in pending) {
      try {
        if ((op['type'] ?? '').toString() != _opTypeCreate) {
          remains.add(op);
          continue;
        }

        final idAsignacion = (op['id_asignacion'] ?? '').toString();
        if (idAsignacion.isEmpty) continue;

        final resp = await http
            .post(
              Uri.parse('$baseUrl/asignaciones/$idAsignacion/calificacion'),
              headers: headers,
              body: jsonEncode(op['payload'] ?? {}),
            )
            .timeout(const Duration(seconds: 10));

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          remains.add(op);
        }
      } catch (_) {
        remains.add(op);
      }
    }

    await _offlineSync.replacePendingOperations(remains);
  }
}
