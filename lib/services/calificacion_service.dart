import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class CalificacionService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

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
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/asignaciones/$idAsignacion/calificacion'),
      headers: headers,
      body: jsonEncode({
        'estrellas': estrellas,
        'comentario': comentario,
        'confirmo_estado': confirmoEstado,
      }),
    );
    if (resp.statusCode == 201) {
      return Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    }
    final error = jsonDecode(resp.body);
    throw Exception(error['detail'] ?? 'Error al registrar calificación');
  }
}
