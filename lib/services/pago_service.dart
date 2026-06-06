import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PagoService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> obtenerResumen(String idSolicitud) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.get(
      Uri.parse('$baseUrl/pagos/solicitudes/$idSolicitud/resumen'),
      headers: headers,
    ).timeout(const Duration(seconds: 20));

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener resumen de pagos: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> crearPaymentIntent(String idSolicitud, double monto) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/pagos/solicitudes/$idSolicitud/stripe/payment-intent'),
      headers: headers,
      body: jsonEncode({'monto': monto}),
    ).timeout(const Duration(seconds: 25));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al crear payment intent: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> confirmarPago(String idSolicitud, String paymentIntentId) async {
    final headers = await _authService.getAuthHeaders();
    final resp = await http.post(
      Uri.parse('$baseUrl/pagos/solicitudes/$idSolicitud/stripe/confirm'),
      headers: headers,
      body: jsonEncode({'payment_intent_id': paymentIntentId}),
    ).timeout(const Duration(seconds: 25));

    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Error al confirmar pago: ${resp.statusCode}');
  }
}
