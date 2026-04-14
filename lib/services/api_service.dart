import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'https://emergencias-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _authService.getAuthHeaders();
      print('GET Request Headers: $headers');  // DEBUG
      print('GET Request URL: $baseUrl$endpoint');  // DEBUG
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      print('GET Response Status: ${response.statusCode}');  // DEBUG
      print('GET Response Body: ${response.body}');  // DEBUG
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en GET $endpoint: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en POST $endpoint: $e');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en PUT $endpoint: $e');
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en PATCH $endpoint: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Error en DELETE $endpoint: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('No autorizado. Inicia sesión nuevamente.');
    } else if (response.statusCode == 403) {
      throw Exception('No tienes permisos para esta acción.');
    } else if (response.statusCode == 404) {
      throw Exception('Recurso no encontrado.');
    } else if (response.statusCode == 500) {
      throw Exception('Error del servidor. Intenta más tarde.');
    } else {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error: ${response.statusCode}');
      } catch (e) {
        throw Exception('Error: ${response.statusCode} - ${response.body}');
      }
    }
  }
}
