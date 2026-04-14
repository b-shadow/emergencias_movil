import '../models/vehiculo.dart';
import 'api_service.dart';

class VehiculoService {
  final ApiService _apiService = ApiService();

  // Obtener vehículos del usuario autenticado
  Future<List<Vehiculo>> getVehiculos() async {
    try {
      final response = await _apiService.get('/clientes/me/vehiculos');
      if (response is List) {
        return response.map((v) => Vehiculo.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error al obtener vehículos: $e');
    }
  }

  // Crear nuevo vehículo
  Future<Vehiculo> createVehiculo({
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    String? color,
    String? tipoCombustible,
    String? observaciones,
  }) async {
    try {
      final payload = {
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
      };
      if (color != null) payload['color'] = color;
      if (tipoCombustible != null) payload['tipo_combustible'] = tipoCombustible;
      if (observaciones != null) payload['observaciones'] = observaciones;
      
      final response = await _apiService.post('/clientes/me/vehiculos', payload);
      return Vehiculo.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear vehículo: $e');
    }
  }

  // Actualizar vehículo
  Future<Vehiculo> updateVehiculo({
    required String id,
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    String? color,
    String? tipoCombustible,
    String? observaciones,
  }) async {
    try {
      final payload = {
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
      };
      if (color != null) payload['color'] = color;
      if (tipoCombustible != null) payload['tipo_combustible'] = tipoCombustible;
      if (observaciones != null) payload['observaciones'] = observaciones;
      
      final response = await _apiService.put('/clientes/me/vehiculos/$id', payload);
      return Vehiculo.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar vehículo: $e');
    }
  }

  // Eliminar vehículo
  Future<void> deleteVehiculo(String id) async {
    try {
      await _apiService.delete('/clientes/me/vehiculos/$id');
    } catch (e) {
      throw Exception('Error al eliminar vehículo: $e');
    }
  }
}
