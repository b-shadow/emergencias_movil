class Postulacion {
  final String idPostulacion;
  final String idSolicitud;
  final String idTaller;
  final String nombreTaller;
  final int tiempoEstimadoMin;
  final String? mensajePropuesta;
  final DateTime fechaPostulacion;

  Postulacion({
    required this.idPostulacion,
    required this.idSolicitud,
    required this.idTaller,
    required this.nombreTaller,
    required this.tiempoEstimadoMin,
    this.mensajePropuesta,
    required this.fechaPostulacion,
  });

  factory Postulacion.fromJson(Map<String, dynamic> json) {
    return Postulacion(
      idPostulacion: json['id_postulacion'] ?? '',
      idSolicitud: json['id_solicitud'] ?? '',
      idTaller: json['id_taller'] ?? '',
      nombreTaller: json['nombre_taller'] ?? 'Taller',
      tiempoEstimadoMin: json['tiempo_estimado_llegada_min'] ?? 0,
      mensajePropuesta: json['mensaje_propuesta'],
      fechaPostulacion: json['fecha_postulacion'] != null
          ? DateTime.parse(json['fecha_postulacion'])
          : DateTime.now(),
    );
  }
}
