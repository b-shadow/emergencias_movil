import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/solicitud.dart';
import 'auth_service.dart';

class SolicitudService {
  static const String baseUrl = 'https://emergencias-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  // Obtener todas las solicitudes del usuario
  Future<List<Solicitud>> obtenerSolicitudes() async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/solicitudes_emergencia'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Solicitud.fromJson(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        return []; // Sin solicitudes
      } else {
        throw Exception('Error al obtener solicitudes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Obtener detalle de una solicitud específica
  Future<Solicitud> obtenerDetalleSolicitud(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Solicitud.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Solicitud no encontrada');
      } else {
        throw Exception('Error al obtener solicitud: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Cancelar solicitud
  Future<Map<String, dynamic>> cancelarSolicitud(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final body = {
        'motivo_cancelacion': 'Cancelada por el cliente desde la aplicación móvil',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud/cancel'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Solicitud no encontrada');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'No se puede cancelar esta solicitud');
      } else {
        throw Exception('Error al cancelar solicitud: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Actualizar solicitud (para editar campos)
  Future<Map<String, dynamic>> actualizarSolicitud(
    String idSolicitud, {
    String? descripcion,
    String? nivelUrgencia,
    double? radioEstadio,
    String? categoria,
    List<String>? idEspecialidades,
    List<String>? idServicios,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final body = {};
      
      if (descripcion != null) body['descripcion_texto'] = descripcion;
      if (nivelUrgencia != null) body['nivel_urgencia'] = nivelUrgencia;
      if (radioEstadio != null) body['radio_busqueda_km'] = radioEstadio;
      if (categoria != null) body['categoria_incidente'] = categoria;
      if (idEspecialidades != null) body['id_especialidades'] = idEspecialidades;
      if (idServicios != null) body['id_servicios'] = idServicios;

      final response = await http.put(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Error al actualizar solicitud');
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Obtener historial de estados de una solicitud
  Future<List<Map<String, dynamic>>> obtenerHistorialEstados(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/solicitudes_emergencia/$idSolicitud/historial'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada');
      } else {
        throw Exception('Error al obtener historial: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
