import 'package:flutter/material.dart';
import '../services/vehiculo_service.dart';

class CreateVehiculoScreen extends StatefulWidget {
  const CreateVehiculoScreen({Key? key}) : super(key: key);

  @override
  State<CreateVehiculoScreen> createState() => _CreateVehiculoScreenState();
}

class _CreateVehiculoScreenState extends State<CreateVehiculoScreen> {
  final VehiculoService _vehiculoService = VehiculoService();
  final _formKey = GlobalKey<FormState>();
  
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  final _combustibleController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _placaController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _colorController.dispose();
    _combustibleController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _crearVehiculo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _vehiculoService.createVehiculo(
        placa: _placaController.text,
        marca: _marcaController.text,
        modelo: _modeloController.text,
        anio: int.parse(_anioController.text),
        color: _colorController.text.isEmpty ? null : _colorController.text,
        tipoCombustible: _combustibleController.text.isEmpty ? null : _combustibleController.text,
        observaciones: _observacionesController.text.isEmpty ? null : _observacionesController.text,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Vehículo'),
        backgroundColor: const Color(0xFF6B46C1),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _placaController,
                decoration: InputDecoration(
                  labelText: 'Placa *',
                  hintText: 'Ej: 1234-ABC',
                  prefixIcon: const Icon(Icons.confirmation_number),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La placa es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _marcaController,
                decoration: InputDecoration(
                  labelText: 'Marca *',
                  hintText: 'Ej: Toyota',
                  prefixIcon: const Icon(Icons.directions_car),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'La marca es requerida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modeloController,
                decoration: InputDecoration(
                  labelText: 'Modelo *',
                  hintText: 'Ej: Hilux',
                  prefixIcon: const Icon(Icons.style),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El modelo es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _anioController,
                decoration: InputDecoration(
                  labelText: 'Año *',
                  hintText: '2021',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'El año es requerido';
                  }
                  final anio = int.tryParse(value);
                  if (anio == null || anio < 1900 || anio > 2100) {
                    return 'Ingresa un año válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _colorController,
                decoration: InputDecoration(
                  labelText: 'Color',
                  hintText: 'Ej: Negro, Blanco, Rojo',
                  prefixIcon: const Icon(Icons.palette),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _combustibleController,
                decoration: InputDecoration(
                  labelText: 'Tipo de Combustible',
                  hintText: 'Ej: Gasolina, Diesel, Hibrido',
                  prefixIcon: const Icon(Icons.local_gas_station),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacionesController,
                decoration: InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Ej: Espejo roto, rayon en puerta',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _crearVehiculo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B46C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Crear Vehículo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
