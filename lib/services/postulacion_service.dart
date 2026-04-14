import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/postulacion.dart';
import 'auth_service.dart';

class PostulacionService {
  static const String baseUrl = 'https://emergencias-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  // Obtener postulaciones de una solicitud específica
  Future<List<Postulacion>> obtenerPostulacionesSolicitud(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/postulaciones/solicitud/$idSolicitud'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Postulacion.fromJson(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        return []; // Sin postulaciones
      } else {
        throw Exception('Error al obtener postulaciones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Obtener mis postulaciones (del taller actual)
  Future<List<Postulacion>> obtenerMisPostulaciones() async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/postulaciones/mis-postulaciones'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Postulacion.fromJson(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        return []; // Sin postulaciones
      } else {
        throw Exception('Error al obtener postulaciones: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Retirar una postulación
  Future<Map<String, dynamic>> retirarPostulacion(String idPostulacion) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Postulación no encontrada');
      } else {
        throw Exception('Error al retirar postulación: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Aceptar postulación (seleccionar taller)
  Future<Map<String, dynamic>> aceptarPostulacion(String idPostulacion) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion/accept'),
        headers: headers,
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Postulación no encontrada');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        final detail = error['detail'] ?? 'Error desconocido';
        throw Exception(detail);
      } else {
        throw Exception('Error al aceptar postulación: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
