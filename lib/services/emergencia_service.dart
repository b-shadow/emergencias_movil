import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class EmergenciaService {
  static String get baseUrl => AuthService.baseUrl;
  static const int visionTimeoutSeconds = int.fromEnvironment(
    'VISION_TIMEOUT_SECONDS',
    defaultValue: 90,
  );
  static const String visionServiceUrl = String.fromEnvironment(
    'VISION_SERVICE_URL',
    defaultValue: 'http://10.0.2.2:8001',
  );
  static const String visionServiceToken = String.fromEnvironment(
    'VISION_SERVICE_TOKEN',
    defaultValue: '',
  );
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

      final response = await http
          .post(
            Uri.parse('$baseUrl/solicitudes_emergencia'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

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

      final response = await http
          .get(
            Uri.parse('$baseUrl/clientes/emergencias'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

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

      final response = await http
          .post(
            Uri.parse('$baseUrl/clientes/emergencia/$idSolicitud/cancelar'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

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

  // Procesar imagen de incidente contra microservicio IA
  Future<Map<String, dynamic>> procesarImagenIncidente({
    File? imagenArchivo,
    List<int>? imagenBytes,
    String? fileName,
    String? evidenciaId,
  }) async {
    try {
      if (imagenArchivo == null &&
          (imagenBytes == null || imagenBytes.isEmpty)) {
        throw Exception('Debes enviar un archivo o bytes de imagen');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$visionServiceUrl/predict/image'),
      );

      if (visionServiceToken.isNotEmpty) {
        request.headers['X-Service-Token'] = visionServiceToken;
      }

      if (evidenciaId != null && evidenciaId.isNotEmpty) {
        request.fields['evidencia_id'] = evidenciaId;
      }

      if (imagenBytes != null && imagenBytes.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imagenBytes,
            filename: fileName ?? 'evidencia.jpg',
          ),
        );
      } else if (imagenArchivo != null) {
        if (kIsWeb) {
          throw Exception('En web se requieren bytes de imagen, no una ruta de archivo');
        }
        request.files.add(
          await http.MultipartFile.fromPath('image', imagenArchivo.path),
        );
      }

      final streamedResponse = await request.send().timeout(
            Duration(seconds: visionTimeoutSeconds),
          );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      String detail = 'Error al procesar imagen: ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    } on TimeoutException {
      throw Exception(
        'Tiempo de espera agotado al procesar con IA (${visionTimeoutSeconds}s)',
      );
    } catch (e) {
      throw Exception('No se pudo procesar la imagen con IA: $e');
    }
  }

  // Procesar descripción del problema con IA (backend -> Groq)
  Future<Map<String, dynamic>> procesarProblemaTexto({
    required String textoProblema,
    String? idVehiculo,
    String? categoriaIncidente,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final body = <String, dynamic>{
        'texto': textoProblema,
      };
      if (idVehiculo != null && idVehiculo.isNotEmpty) {
        body['id_vehiculo'] = idVehiculo;
      }
      if (categoriaIncidente != null && categoriaIncidente.isNotEmpty) {
        body['categoria_incidente'] = categoriaIncidente;
      }
      final response = await http
          .post(
            Uri.parse(
                '$baseUrl/solicitudes_emergencia/tools/procesar-problema'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 35));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return (decoded['data'] ?? {}) as Map<String, dynamic>;
        }
        throw Exception(decoded['error'] ?? 'No se pudo procesar el problema');
      }

      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['detail'] ??
                decoded['error'] ??
                'Error ${response.statusCode}')
            : 'Error ${response.statusCode}',
      );
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado al procesar el problema');
    } catch (e) {
      throw Exception('No se pudo procesar el problema con IA: $e');
    }
  }

  // Sugerencia inteligente de servicio/especialidad previa a crear solicitud
  Future<Map<String, dynamic>> sugerirServicioInteligente({
    required String descripcion,
    required String idVehiculo,
    String? categoriaIncidente,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final body = <String, dynamic>{
        'descripcion': descripcion,
        'id_vehiculo': idVehiculo,
      };
      if (categoriaIncidente != null && categoriaIncidente.isNotEmpty) {
        body['categoria_incidente'] = categoriaIncidente;
      }

      final response = await http
          .post(
            Uri.parse(
                '$baseUrl/solicitudes_emergencia/tools/sugerir-servicio-inteligente'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(decoded as Map);
      }
      throw Exception(
        decoded is Map<String, dynamic>
            ? (decoded['detail'] ?? decoded['error'] ?? 'Error ${response.statusCode}')
            : 'Error ${response.statusCode}',
      );
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado al obtener sugerencia inteligente');
    } catch (e) {
      throw Exception('No se pudo obtener sugerencia inteligente: $e');
    }
  }

  // Subir/reemplazar imagen de evidencia para una solicitud
  Future<Map<String, dynamic>> subirImagenEvidenciaSolicitud({
    required String solicitudId,
    required File imagenArchivo,
    String? descripcion,
  }) async {
    try {
      final token = await _authService.getStoredToken();
      if (token == null || token.isEmpty) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '$baseUrl/solicitudes_emergencia/$solicitudId/evidencias/imagen'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      if (descripcion != null && descripcion.trim().isNotEmpty) {
        request.fields['descripcion'] = descripcion.trim();
      }

      request.files.add(
        await http.MultipartFile.fromPath('archivo', imagenArchivo.path),
      );

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      String detail = 'Error subiendo evidencia: ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    } catch (e) {
      throw Exception('No se pudo subir la imagen de evidencia: $e');
    }
  }

  // Obtener evidencias de una solicitud
  Future<List<Map<String, dynamic>>> obtenerEvidenciasSolicitud(
      String solicitudId) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/solicitudes_emergencia/$solicitudId/evidencias'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (response.statusCode == 401) {
        throw Exception('Sesión expirada. Inicia sesión nuevamente.');
      }

      throw Exception('Error al obtener evidencias: ${response.statusCode}');
    } catch (e) {
      throw Exception('No se pudo obtener evidencias: $e');
    }
  }
}
