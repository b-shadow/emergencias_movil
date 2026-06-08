import 'package:flutter/material.dart';
import '../models/vehiculo.dart';
import '../services/vehiculo_service.dart';
import 'create_vehiculo_screen.dart';
import 'edit_vehiculo_screen.dart';
import 'emergencia_screen.dart';
import '../widgets/theme_toggle_button.dart';

class VehiculosScreen extends StatefulWidget {
  final String? seleccionarPara;

  const VehiculosScreen({super.key, this.seleccionarPara});

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  final VehiculoService _vehiculoService = VehiculoService();

  List<Vehiculo> _vehiculos = [];
  bool _isLoading = true;
  String? _error;

  bool get _esSeleccion => widget.seleccionarPara == 'emergencia';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final vehiculos = await _vehiculoService.getVehiculos();
      if (!mounted) return;

      setState(() {
        _vehiculos = vehiculos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final error = e.toString();
        if (error.contains('OFFLINE_NO_CACHE_VEHICULOS')) {
          _error =
              'No hay vehículos disponibles sin conexión todavía.\nAbre esta pantalla al menos una vez con internet para guardarlos localmente.';
        } else {
          _error = 'Error: $e';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarVehiculo(String id) async {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('¿Deseas eliminar este vehículo?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await _vehiculoService.deleteVehiculo(id);
                  _cargarDatos();
                  if (!rootContext.mounted) return;
                  if (mounted) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(content: Text('Vehículo eliminado')),
                    );
                  }
                } catch (e) {
                  if (!rootContext.mounted) return;
                  if (mounted) {
                    String msg = 'Error: $e';
                    if (e.toString().contains('404')) {
                      msg = 'El vehículo no está disponible';
                    }
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                }
              },
              child: const Text('Sí', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editarVehiculo(Vehiculo v) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditVehiculoScreen(vehiculo: v)),
    );
    if (result == true) _cargarDatos();
  }

  Future<void> _crearVehiculo() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateVehiculoScreen()),
    );
    if (result == true) _cargarDatos();
  }

  void _seleccionarParaEmergencia(Vehiculo v) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => EmergenciaScreen(vehiculoAfectado: v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _cargarDatos,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _vehiculos.isEmpty
                        ? _buildEmptyState()
                        : _buildVehiculosList(isDark),
          ),
        ],
      ),
      floatingActionButton: !_esSeleccion
          ? FloatingActionButton.extended(
              onPressed: _crearVehiculo,
              backgroundColor: const Color(0xFF5B3DF5),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            )
          : null,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _esSeleccion
              ? const [Color(0xFFFF6E6E), Color(0xFFFF4D57)]
              : const [Color(0xFF6A4BFF), Color(0xFF4B2ED8)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),
            Expanded(
              child: Text(
                _esSeleccion ? 'Selecciona un vehículo' : 'Vehículos',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const ThemeToggleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.directions_car_outlined, size: 84),
          const SizedBox(height: 14),
          Text(
            _esSeleccion ? 'No tienes vehículos para seleccionar' : 'Sin vehículos registrados',
          ),
          if (!_esSeleccion) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _crearVehiculo,
              icon: const Icon(Icons.add),
              label: const Text('Agregar vehículo'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehiculosList(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (_esSeleccion) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2230) : const Color(0xFFFFF7F7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFB3B3)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFFFE5E5),
                  child: Icon(Icons.verified_user_outlined, color: Color(0xFFFF4D57), size: 30),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elige el vehículo',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text('para continuar con tu solicitud', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tus vehículos',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFD7CEF9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car_outlined, color: Color(0xFF6A4BFF)),
                    const SizedBox(width: 6),
                    Text('${_vehiculos.length} registrados'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gestiona, edita y agrega tus vehículos registrados',
            style: TextStyle(
              fontSize: 17,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ..._vehiculos.map((v) => _buildVehiculoCard(v, isDark)),
      ],
    );
  }

  Widget _buildVehiculoCard(Vehiculo v, bool isDark) {
    return GestureDetector(
      onTap: _esSeleccion ? () => _seleccionarParaEmergencia(v) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2030) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _esSeleccion
                ? const Color(0xFFE6E7EB)
                : const Color(0xFFE7E9F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _esSeleccion
                        ? const Color(0xFFF1F2F5)
                        : const Color(0xFFEDEAFF),
                  ),
                  child: Icon(
                    Icons.directions_car_filled_outlined,
                    size: 34,
                    color: _esSeleccion
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF5B3DF5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.placa,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${v.marca} ${v.modelo} (${v.anio})',
                        style: TextStyle(
                          fontSize: 17,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_esSeleccion)
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                    size: 34,
                  ),
              ],
            ),
            if (!_esSeleccion) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editarVehiculo(v),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B3DF5),
                      side: const BorderSide(color: Color(0xFF5B3DF5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _eliminarVehiculo(v.id),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}





