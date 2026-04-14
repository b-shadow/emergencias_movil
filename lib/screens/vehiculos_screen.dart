import 'package:flutter/material.dart';
import '../models/vehiculo.dart';
import '../services/vehiculo_service.dart';
import 'create_vehiculo_screen.dart';
import 'edit_vehiculo_screen.dart';
import 'emergencia_screen.dart';

class VehiculosScreen extends StatefulWidget {
  final String? seleccionarPara;

  const VehiculosScreen({Key? key, this.seleccionarPara}) : super(key: key);

  @override
  State<VehiculosScreen> createState() => _VehiculosScreenState();
}

class _VehiculosScreenState extends State<VehiculosScreen> {
  final VehiculoService _vehiculoService = VehiculoService();

  List<Vehiculo> _vehiculos = [];
  bool _isLoading = true;
  String? _error;

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

      setState(() {
        _vehiculos = vehiculos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _eliminarVehiculo(String id) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¿Deseas eliminar este vehículo?'),
          content: const Text('Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _vehiculoService.deleteVehiculo(id);
                  _cargarDatos();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vehículo eliminado')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    String msg = 'Error: $e';
                    if (e.toString().contains('404')) {
                      msg = 'El vehículo no está disponible';
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
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
    final esSeleccion = widget.seleccionarPara == 'emergencia';

    return Scaffold(
      appBar: AppBar(
        title: Text(esSeleccion ? 'Selecciona un vehículo' : 'Vehículos'),
        backgroundColor: esSeleccion ? const Color(0xFFFF6B6B) : const Color(0xFF6B46C1),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      ElevatedButton(
                        onPressed: _cargarDatos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _vehiculos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car, size: 80),
                          const SizedBox(height: 20),
                          const Text('Sin vehículos'),
                          if (!esSeleccion)
                            ElevatedButton(
                              onPressed: _crearVehiculo,
                              child: const Text('Agregar'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _vehiculos.length,
                      itemBuilder: (_, i) {
                        final v = _vehiculos[i];
                        if (esSeleccion) {
                          // Modo selección para emergencia
                          return ListTile(
                            title: Text(v.placa),
                            subtitle: Text('${v.marca} ${v.modelo} (${v.anio})'),
                            trailing: const Icon(Icons.arrow_forward),
                            onTap: () => _seleccionarParaEmergencia(v),
                          );
                        } else {
                          // Modo normal de gestión
                          return ListTile(
                            title: Text(v.placa),
                            subtitle: Text('${v.marca} ${v.modelo} (${v.anio})'),
                            trailing: PopupMenuButton(
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  onTap: () => _editarVehiculo(v),
                                  child: const Text('Editar'),
                                ),
                                PopupMenuItem(
                                  onTap: () => _eliminarVehiculo(v.id),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
      floatingActionButton: !esSeleccion
          ? FloatingActionButton(
              onPressed: _crearVehiculo,
              backgroundColor: const Color(0xFF6B46C1),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
