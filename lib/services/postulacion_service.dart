import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/postulacion.dart';
import 'auth_service.dart';
import 'offline_sync_service.dart';

class PostulacionService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();
  final OfflineSyncService _offlineSync = OfflineSyncService();

  static const String _cachePostulacionesSolicitudPrefix =
      'cache_postulaciones_solicitud_';
  static const String _cacheMisPostulaciones = 'cache_mis_postulaciones';
  static const String _cacheCotizacionPrefix = 'cache_cotizacion_postulacion_';

  bool _isConnectivityError(Object error) {
    final text = error.toString();
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('timed out');
  }

  Future<List<Postulacion>> obtenerPostulacionesSolicitud(
      String idSolicitud) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/postulaciones/solicitud/$idSolicitud'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await _offlineSync.cacheJson(
          '$_cachePostulacionesSolicitudPrefix$idSolicitud',
          data,
        );
        return data
            .map((item) => Postulacion.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesion expirada. Inicia sesion nuevamente.');
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Error al obtener postulaciones: ${response.statusCode}');
      }
    } catch (e) {
      final cached = await _offlineSync
          .getCachedJson('$_cachePostulacionesSolicitudPrefix$idSolicitud');
      if (cached is List) {
        return cached
            .map((item) =>
                Postulacion.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_POSTULACIONES');
      }
      throw Exception('Error: $e');
    }
  }

  Future<List<Postulacion>> obtenerMisPostulaciones() async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/postulaciones/mis-postulaciones'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await _offlineSync.cacheJson(_cacheMisPostulaciones, data);
        return data
            .map((item) => Postulacion.fromJson(item as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesion expirada. Inicia sesion nuevamente.');
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Error al obtener postulaciones: ${response.statusCode}');
      }
    } catch (e) {
      final cached = await _offlineSync.getCachedJson(_cacheMisPostulaciones);
      if (cached is List) {
        return cached
            .map((item) =>
                Postulacion.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_MIS_POSTULACIONES');
      }
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> retirarPostulacion(String idPostulacion) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion/withdraw'),
        headers: headers,
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Sesion expirada. Inicia sesion nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Postulacion no encontrada');
      } else {
        throw Exception('Error al retirar postulacion: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> aceptarPostulacion(String idPostulacion,
      {String? idTrabajador}) async {
    try {
      final headers = await _authService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion/accept'),
        headers: headers,
        body: jsonEncode({
          if (idTrabajador != null) 'id_trabajador': idTrabajador,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Sesion expirada. Inicia sesion nuevamente.');
      } else if (response.statusCode == 404) {
        throw Exception('Postulacion no encontrada');
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        final detail = error['detail'] ?? 'Error desconocido';
        throw Exception(detail);
      } else {
        throw Exception('Error al aceptar postulacion: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> crearOActualizarCotizacion(
    String idPostulacion, {
    required List<Map<String, dynamic>> servicios,
    String? tipoPintura,
    String? detalle,
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final payload = {
        'servicios': servicios,
        if (tipoPintura != null) 'tipo_pintura': tipoPintura,
        if (detalle != null) 'detalle': detalle,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion/cotizacion'),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error al guardar cotizacion: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerCotizacion(String idPostulacion) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion/cotizacion'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _offlineSync.cacheJson('$_cacheCotizacionPrefix$idPostulacion', data);
        return data;
      }
      throw Exception('Error al obtener cotizacion: ${response.statusCode}');
    } catch (e) {
      final cached =
          await _offlineSync.getCachedJson('$_cacheCotizacionPrefix$idPostulacion');
      if (cached is Map) {
        return Map<String, dynamic>.from(cached);
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_COTIZACION');
      }
      throw Exception('Error: $e');
    }
  }

  Future<Map<String, dynamic>> decidirCotizacion(
      String idPostulacion, bool aceptar) async {
    try {
      final headers = await _authService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/postulaciones/$idPostulacion/cotizacion/decision'),
        headers: headers,
        body: jsonEncode({'aceptar': aceptar}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error al responder cotizacion: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
