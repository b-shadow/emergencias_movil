class Notificacion {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final String categoria;
  final String estado;
  final DateTime fecha;
  final String? referenciaEntidad;
  final String? referenciaId;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.categoria,
    required this.estado,
    required this.fecha,
    this.referenciaEntidad,
    this.referenciaId,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id_notificacion'] ?? '',
      titulo: json['titulo'] ?? '',
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo_notificacion'] ?? '',
      categoria: json['categoria_evento'] ?? '',
      estado: json['estado_lectura'] ?? 'NO_LEIDA',
      fecha: DateTime.parse(json['fecha_envio'] ?? DateTime.now().toIso8601String()),
      referenciaEntidad: json['referencia_entidad'],
      referenciaId: json['referencia_id'],
    );
  }

  bool get esNoLeida => estado == 'NO_LEIDA';

  Map<String, dynamic> toJson() {
    return {
      'id_notificacion': id,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo_notificacion': tipo,
      'categoria_evento': categoria,
      'estado_lectura': estado,
      'fecha_envio': fecha.toIso8601String(),
      'referencia_entidad': referenciaEntidad,
      'referencia_id': referenciaId,
    };
  }
}

class NotificacionResponse {
  final int total;
  final int noLeidas;
  final List<Notificacion> items;

  NotificacionResponse({
    required this.total,
    required this.noLeidas,
    required this.items,
  });

  factory NotificacionResponse.fromJson(Map<String, dynamic> json) {
    var items = (json['items'] as List?)
        ?.map((item) => Notificacion.fromJson(item as Map<String, dynamic>))
        .toList() ?? [];

    return NotificacionResponse(
      total: json['total'] ?? 0,
      noLeidas: json['no_leidas'] ?? 0,
      items: items,
    );
  }
}
