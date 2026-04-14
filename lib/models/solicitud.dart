class Solicitud {
  final String idSolicitud;
  final String codigoSolicitud;
  final String estado;
  final String vehiculo;
  final String nivelUrgencia;
  final String? categoria;
  final double radioEstadio;
  final double? latitud;
  final double? longitud;
  final String? descripcion;
  final DateTime fechaCreacion;
  final List<String> especialidadesRequeridas;
  final List<String> serviciosRequeridos;

  Solicitud({
    required this.idSolicitud,
    required this.codigoSolicitud,
    required this.estado,
    required this.vehiculo,
    required this.nivelUrgencia,
    this.categoria,
    required this.radioEstadio,
    this.latitud,
    this.longitud,
    this.descripcion,
    required this.fechaCreacion,
    this.especialidadesRequeridas = const [],
    this.serviciosRequeridos = const [],
  });

  factory Solicitud.fromJson(Map<String, dynamic> json) {
    return Solicitud(
      idSolicitud: json['id_solicitud'] ?? '',
      codigoSolicitud: json['codigo_solicitud'] ?? '',
      estado: json['estado_actual'] ?? 'REGISTRADA',
      vehiculo: json['vehiculo'] ?? 'Vehículo',
      nivelUrgencia: json['nivel_urgencia'] ?? 'MEDIO',
      categoria: json['categoria_incidente'],
      radioEstadio: (json['radio_busqueda_km'] ?? 5.0).toDouble(),
      latitud: json['latitud'] != null ? (json['latitud'] as num).toDouble() : null,
      longitud: json['longitud'] != null ? (json['longitud'] as num).toDouble() : null,
      descripcion: json['descripcion_texto'],
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : DateTime.now(),
      especialidadesRequeridas: List<String>.from(json['especialidades_requeridas'] ?? json['id_especialidades'] ?? json['especialidades'] ?? []),
      serviciosRequeridos: List<String>.from(json['servicios_requeridos'] ?? json['id_servicios'] ?? json['servicios'] ?? []),
    );
  }
}
