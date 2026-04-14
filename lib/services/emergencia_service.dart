import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EmergenciaService {
  static const String baseUrl = 'https://emergencias-backend.onrender.com/api/v1';
  final AuthService _authService = AuthService();

  // Crear solicitud de emergencia
  Future<Map<String, dynamic>> crearSolicitudEmergencia({
    required String idVehiculo,
    required String descripcion,
    required String nivelUrgencia,
    required double latitud,
    required double longitud,
    required double radioEstadio,
    required String codigoSolicitud,
    required List<String> idEspecialidades,
    required List<String> idServicios,
    String? categoria,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      
      final body = {
        'codigo_solicitud': codigoSolicitud,
        'descripcion_texto': descripcion,
        'nivel_urgencia': nivelUrgencia,
        'latitud': latitud,
        'longitud': longitud,
        'radio_busqueda_km': radioEstadio,
        'id_vehiculo': idVehiculo,
        'id_especialidades': idEspecialidades,
        'id_servicios': idServicios,
      };

      // Agregar categoría si se proporciona
      if (categoria != null && categoria.isNotEmpty) {
        body['categoria_incidente'] = categoria;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/solicitudes_emergencia'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Solicitud inválida');
      } else {
        throw Exception('Error al crear solicitud: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Obtener solicitudes del usuario
  Future<List<Map<String, dynamic>>> getSolicitudes() async {
    try {
      final headers = await _authService.getAuthHeaders();
      
      final response = await http.get(
        Uri.parse('$baseUrl/clientes/emergencias'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Error al obtener solicitudes');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Cancelar solicitud de emergencia
  Future<void> cancelarSolicitud(String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();
      
      final response = await http.post(
        Uri.parse('$baseUrl/clientes/emergencia/$idSolicitud/cancelar'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar solicitud');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Convertir imagen a base64 para enviar al backend
  static String imageToBase64(List<int> imageBytes) {
    return base64Encode(imageBytes);
  }
}
