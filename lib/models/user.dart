class Usuario {
  final String idUsuario;
  final String correo;
  final String nombreCompleto;
  final String rol;
  final bool esActivo;

  Usuario({
    required this.idUsuario,
    required this.correo,
    required this.nombreCompleto,
    required this.rol,
    required this.esActivo,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idUsuario: json['id_usuario'].toString(),
      correo: json['correo'] ?? '',
      nombreCompleto: json['nombre_completo'] ?? '',
      rol: json['rol'] ?? 'CLIENTE',
      esActivo: json['es_activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_usuario': idUsuario,
      'correo': correo,
      'nombre_completo': nombreCompleto,
      'rol': rol,
      'es_activo': esActivo,
    };
  }
}

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String rol;
  final String idUsuario;
  final String nombreCompleto;
  final String correo;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.rol,
    required this.idUsuario,
    required this.nombreCompleto,
    required this.correo,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      rol: json['rol'] ?? 'CLIENTE',
      idUsuario: json['id_usuario'].toString(),
      nombreCompleto: json['nombre_completo'] ?? '',
      correo: json['correo'] ?? '',
    );
  }
}
