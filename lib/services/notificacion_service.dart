import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notificacion.dart';
import 'auth_service.dart';

class NotificacionService {
  static const String baseUrl = 'https://emergencias-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

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
        return NotificacionResponse.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        return NotificacionResponse(total: 0, noLeidas: 0, items: []);
      } else {
        throw Exception('Error al obtener notificaciones: ${response.statusCode}');
      }
    } catch (e) {
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
      throw Exception('Error: $e');
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
      throw Exception('Error: $e');
    }
  }
}
