import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthService {
  static const String baseUrl = 'https://emergencias-backend.onrender.com/api/v1';

  Future<TokenResponse> login(String correo, String contrasena) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correo,
          'contrasena': contrasena,
          'client_type': 'mobile', // 'mobile' o 'web'
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Tiempo de conexión agotado. Verifica tu conexión.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tokenResponse = TokenResponse.fromJson(data);

        // Verificar que el rol sea CLIENTE
        if (tokenResponse.rol != 'CLIENTE') {
          throw Exception('Solo clientes pueden ingresar desde la aplicación móvil');
        }

        // Guardar en SharedPreferences
        await _saveTokenLocally(tokenResponse);

        return tokenResponse;
      } else if (response.statusCode == 401) {
        throw Exception('Credenciales inválidas. Verifica correo y contraseña.');
      } else if (response.statusCode == 403) {
        throw Exception('Tu cuenta está desactivada. Contacta a soporte.');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Error al iniciar sesión');
      }
    } on http.ClientException catch (e) {
      throw Exception('Error de conexión: ${e.message}. Verifica tu conexión a internet.');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Future<void> _saveTokenLocally(TokenResponse token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token.accessToken);
    await prefs.setString('refreshToken', token.refreshToken);
    await prefs.setString('userId', token.idUsuario);
    await prefs.setString('userName', token.nombreCompleto);
    await prefs.setString('userEmail', token.correo);  // Guardar email correcto
    await prefs.setString('userRole', token.rol);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  /// Alias para getToken() (usado en main.dart para session boot)
  Future<String?> getStoredToken() async {
    return getToken();
  }

  /// Valida que el token sea aún válido haciendo una llamada al backend
  Future<bool> validateToken() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('[AUTH] Error validando token: $e');
      return false;
    }
  }

  /// Alias para logout() (usado en main.dart)
  Future<void> clearSession() async {
    return logout();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token available');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userRole');
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName');
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  Future<TokenResponse?> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');

      if (refreshToken == null) {
        throw Exception('No hay refresh token guardado');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newToken = TokenResponse.fromJson(data);
        await _saveTokenLocally(newToken);
        return newToken;
      } else {
        throw Exception('No se pudo renovar el token');
      }
    } catch (e) {
      await logout();
      rethrow;
    }
  }

  // Registro de nuevo cliente
  Future<Map<String, dynamic>> registrarCliente({
    required String correo,
    required String contrasena,
    required String confirmarContrasena,
    required String nombre,
    required String apellido,
    String? telefono,
    String? ci,
    String? direccion,
  }) async {
    try {
      final payload = {
        'correo': correo,
        'contrasena': contrasena,
        'confirmar_contrasena': confirmarContrasena,
        'nombre': nombre,
        'apellido': apellido,
      };

      if (telefono != null && telefono.isNotEmpty) {
        payload['telefono'] = telefono;
      }
      if (ci != null && ci.isNotEmpty) {
        payload['ci'] = ci;
      }
      if (direccion != null && direccion.isNotEmpty) {
        payload['direccion'] = direccion;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Tiempo de conexión agotado');
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 422) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Datos inválidos');
      } else if (response.statusCode == 409) {
        throw Exception('El correo ya está registrado');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Error al registrarse');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Obtener información del usuario actual
  Future<Usuario?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final userName = prefs.getString('userName');
      final userEmail = prefs.getString('userEmail');
      final userRole = prefs.getString('userRole') ?? 'CLIENTE';
      final isActive = prefs.getBool('isActive') ?? true;

      if (userId == null) {
        return null;
      }

      return Usuario(
        idUsuario: userId,
        correo: userEmail ?? '',
        nombreCompleto: userName ?? '',
        rol: userRole,
        esActivo: isActive,
      );
    } catch (e) {
      return null;
    }
  }
}
