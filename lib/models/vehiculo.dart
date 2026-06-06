class Vehiculo {
  final String id;
  final String placa;
  final String marca;
  final String modelo;
  final int anio;
  final String? color;
  final String? tipoCombustible;
  final String? tipoSeguro;
  final String? aseguradora;
  final String? observaciones;

  Vehiculo({
    required this.id,
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.color,
    this.tipoCombustible,
    this.tipoSeguro,
    this.aseguradora,
    this.observaciones,
  });


  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id_vehiculo'].toString(), 
      placa: json['placa'],
      marca: json['marca'],
      modelo: json['modelo'],
      anio: json['anio'],
      color: json['color'],
      tipoCombustible: json['tipo_combustible'],
      tipoSeguro: json['tipo_seguro'],
      aseguradora: json['aseguradora'],
      observaciones: json['observaciones'],
    );
  }

 
  Map<String, dynamic> toJson() {
    return {
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'color': color,
      'tipo_combustible': tipoCombustible,
      'tipo_seguro': tipoSeguro,
      'aseguradora': aseguradora,
      'observaciones': observaciones,
    };
  }
}
