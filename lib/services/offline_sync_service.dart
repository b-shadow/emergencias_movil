import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncService {
  static const String _queueKey = 'offline_pending_ops';

  Future<void> cacheJson(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  Future<dynamic> getCachedJson(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> enqueueOperation(Map<String, dynamic> op) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    final list = raw != null ? (jsonDecode(raw) as List<dynamic>) : <dynamic>[];
    final normalized = Map<String, dynamic>.from(op);
    normalized.putIfAbsent('queued_at', () => DateTime.now().toIso8601String());
    normalized.putIfAbsent(
      'op_id',
      () => '${normalized['type'] ?? 'op'}_${DateTime.now().microsecondsSinceEpoch}',
    );

    final next = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final replaceIndex = _findReplaceIndex(next, normalized);
    if (replaceIndex >= 0) {
      next[replaceIndex] = normalized;
    } else {
      next.add(normalized);
    }
    await prefs.setString(_queueKey, jsonEncode(next));
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> replacePendingOperations(List<Map<String, dynamic>> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueKey, jsonEncode(ops));
  }

  int _findReplaceIndex(
    List<Map<String, dynamic>> ops,
    Map<String, dynamic> incoming,
  ) {
    final type = (incoming['type'] ?? '').toString();
    for (var i = 0; i < ops.length; i++) {
      final existing = ops[i];
      final existingType = (existing['type'] ?? '').toString();
      if (existingType != type) continue;

      switch (type) {
        case 'solicitud_cancel':
        case 'solicitud_update':
          if ((existing['id_solicitud'] ?? '').toString() ==
              (incoming['id_solicitud'] ?? '').toString()) {
            return i;
          }
          break;
        case 'tracking_update':
        case 'tracking_accept':
        case 'tracking_llegada_auxilio':
        case 'tracking_iniciar_traslado':
        case 'tracking_llegada_taller':
          if ((existing['id_orden'] ?? '').toString() ==
              (incoming['id_orden'] ?? '').toString()) {
            return i;
          }
          break;
        case 'notificacion_marcar_leida':
          if ((existing['id_notificacion'] ?? '').toString() ==
              (incoming['id_notificacion'] ?? '').toString()) {
            return i;
          }
          break;
        case 'notificacion_marcar_todas':
          return i;
        case 'calificacion_create':
          if ((existing['id_asignacion'] ?? '').toString() ==
              (incoming['id_asignacion'] ?? '').toString()) {
            return i;
          }
          break;
      }
    }
    return -1;
  }
}
