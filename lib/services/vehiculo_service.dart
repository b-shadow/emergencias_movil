import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/vehiculo.dart';
import 'api_service.dart';
import 'offline_sync_service.dart';

class VehiculoService {
  final ApiService _apiService = ApiService();
  final OfflineSyncService _offlineSync = OfflineSyncService();

  static const String _cacheVehiculos = 'cache_vehiculos';

  bool _isConnectivityError(Object error) {
    final text = error.toString();
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('timed out');
  }

  Future<List<Vehiculo>> getVehiculos() async {
    try {
      final response = await _apiService.get('/clientes/me/vehiculos');
      if (response is List) {
        await _offlineSync.cacheJson(_cacheVehiculos, response);
        return response.map((v) => Vehiculo.fromJson(v)).toList();
      }
      return [];
    } catch (e) {
      final cached = await _offlineSync.getCachedJson(_cacheVehiculos);
      if (cached is List) {
        return cached
            .map((v) => Vehiculo.fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
      }
      if (_isConnectivityError(e)) {
        throw Exception('OFFLINE_NO_CACHE_VEHICULOS');
      }
      throw Exception('Error al obtener vehículos: $e');
    }
  }

  Future<Vehiculo> createVehiculo({
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    String? color,
    String? tipoCombustible,
    String? tipoSeguro,
    String? aseguradora,
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
      if (tipoSeguro != null) payload['tipo_seguro'] = tipoSeguro;
      if (aseguradora != null) payload['aseguradora'] = aseguradora;
      if (observaciones != null) payload['observaciones'] = observaciones;

      final response = await _apiService.post('/clientes/me/vehiculos', payload);
      return Vehiculo.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear vehículo: $e');
    }
  }

  Future<Vehiculo> updateVehiculo({
    required String id,
    required String placa,
    required String marca,
    required String modelo,
    required int anio,
    String? color,
    String? tipoCombustible,
    String? tipoSeguro,
    String? aseguradora,
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
      if (tipoSeguro != null) payload['tipo_seguro'] = tipoSeguro;
      if (aseguradora != null) payload['aseguradora'] = aseguradora;
      if (observaciones != null) payload['observaciones'] = observaciones;

      final response = await _apiService.patch('/clientes/me/vehiculos/$id', payload);
      return Vehiculo.fromJson(response);
    } catch (e) {
      throw Exception('Error al actualizar vehículo: $e');
    }
  }

  Future<void> deleteVehiculo(String id) async {
    try {
      await _apiService.delete('/clientes/me/vehiculos/$id');
    } catch (e) {
      throw Exception('Error al eliminar vehículo: $e');
    }
  }
}
