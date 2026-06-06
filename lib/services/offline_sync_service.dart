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
    list.add(op);
    await prefs.setString(_queueKey, jsonEncode(list));
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
}
