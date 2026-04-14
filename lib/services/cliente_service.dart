import 'api_service.dart';

class ClienteProfileResponse {
  final String idCliente;
  final String nombre;
  final String apellido;
  final String? telefono;
  final String? ci;
  final String? direccion;
  final String? fotoPerfil;
  final String correo;

  ClienteProfileResponse({
    required this.idCliente,
    required this.nombre,
    required this.apellido,
    this.telefono,
    this.ci,
    this.direccion,
    this.fotoPerfil,
    required this.correo,
  });

  factory ClienteProfileResponse.fromJson(Map<String, dynamic> json) {
    return ClienteProfileResponse(
      idCliente: json['id_cliente'].toString(),
      nombre: json['nombre'],
      apellido: json['apellido'],
      telefono: json['telefono'],
      ci: json['ci'],
      direccion: json['direccion'],
      fotoPerfil: json['foto_perfil_url'],
      correo: json['correo'],
    );
  }
}

class ClienteService {
  final ApiService _apiService = ApiService();

  // Obtener perfil del cliente
  Future<ClienteProfileResponse> getMiPerfil() async {
    try {
      final response = await _apiService.get('/clientes/me');
      return ClienteProfileResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error al obtener perfil: $e');
    }
  }

  // Actualizar perfil del cliente
  Future<ClienteProfileResponse> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
    String? ci,
    String? direccion,
  }) async {
    try {
      final payload = {
        'nombre': nombre,
        'apellido': apellido,
      };
      if (telefono != null && telefono.isNotEmpty) payload['telefono'] = telefono;
      if (ci != null && ci.isNotEmpty) payload['ci'] = ci;
      if (direccion != null && direccion.isNotEmpty) payload['direccion'] = direccion;

      final response = await _apiService.patch('/clientes/me', payload);
      return ClienteProfileResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }
}
