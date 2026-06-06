import 'api_service.dart';

class TenantService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> obtenerTenantTaller() async {
    final data = await _api.get('/talleres/me/tenant');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> obtenerTenantTrabajador() async {
    final data = await _api.get('/trabajadores/me/tenant');
    return Map<String, dynamic>.from(data as Map);
  }
}
