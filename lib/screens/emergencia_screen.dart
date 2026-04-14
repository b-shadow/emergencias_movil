import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/vehiculo.dart';
import '../services/emergencia_service.dart';
import '../services/api_service.dart';

class EmergenciaScreen extends StatefulWidget {
  final Vehiculo vehiculoAfectado;

  const EmergenciaScreen({Key? key, required this.vehiculoAfectado})
      : super(key: key);

  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  final EmergenciaService _emergenciaService = EmergenciaService();
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descripcionController;
  late TextEditingController _latitudController;
  late TextEditingController _longitudController;

  String _nivelUrgencia = 'MEDIO'; // BAJO, MEDIO, ALTO, CRITICO
  String? _categoria; // COLISION_VISIBLE, HUMO_O_SOBRECALENTAMIENTO, PINCHAZO_LLANTA, SIN_HALLAZGOS_CLAROS, VEHICULO_INMOVILIZADO
  double _radioEstadio = 5.0;
  double _latitud = -17.4;
  double _longitud = -66.1;
  bool _isSaving = false;
  late MapController _mapController;
  // Audio y especialidades/servicios
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  List<Map<String, dynamic>> _especialidades = [];
  List<Map<String, dynamic>> _servicios = [];
  Set<String> _especialidadesSeleccionadas = {};
  Set<String> _serviciosSeleccionados = {};
  bool _loadingEspecialidades = true;
  bool _loadingServicios = true;
  // Cámara y fotos
  File? _fotoTomada;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _descripcionController = TextEditingController();
    _latitudController = TextEditingController(text: _latitud.toString());
    _longitudController = TextEditingController(text: _longitud.toString());
    
    _speechToText = stt.SpeechToText();
    _initializeSpeechToText();
    
    // Retardar la obtención de ubicación después de que el widget esté construido
    Future.delayed(const Duration(milliseconds: 100), () {
      _obtenerUbicacion();
      _cargarEspecialidades();
      _cargarServicios();
    });
  }

  Future<void> _initializeSpeechToText() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) => print('Error Speech To Text: $error'),
        onStatus: (status) => print('Status: $status'),
      );
      if (!available) {
        print('Speech to text no disponible en este dispositivo');
      }
    } catch (e) {
      print('Error inicializando speech to text: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      // Solicitar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permisos de ubicación denegados permanentemente'),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Obtener ubicación actual
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        
        setState(() {
          _latitud = position.latitude;
          _longitud = position.longitude;
          _latitudController.text = _latitud.toStringAsFixed(4);
          _longitudController.text = _longitud.toStringAsFixed(4);
          // Actualizar el mapa
          _mapController.move(LatLng(_latitud, _longitud), 15);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ubicación obtenida correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener ubicación: $e')),
        );
      }
    }
  }

  Future<void> _reintentarUbicacion() async {
    await _obtenerUbicacion();
  }

  Future<void> _enviarEmergencia() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los campos requeridos')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Generar código único para la solicitud
      final codigoSolicitud = 'SEM-${DateTime.now().millisecondsSinceEpoch}';

      await _emergenciaService.crearSolicitudEmergencia(
        idVehiculo: widget.vehiculoAfectado.id,
        descripcion: _descripcionController.text,
        nivelUrgencia: _nivelUrgencia,
        latitud: _latitud,
        longitud: _longitud,
        radioEstadio: _radioEstadio,
        codigoSolicitud: codigoSolicitud,
        idEspecialidades: _especialidadesSeleccionadas.toList(),
        idServicios: _serviciosSeleccionados.toList(),
        categoria: _categoria,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Emergencia registrada correctamente',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF40C057),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
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
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _descripcionController.dispose();
    _latitudController.dispose();
    _longitudController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  // Cargar especialidades desde API (endpoint público)
  Future<void> _cargarEspecialidades() async {
    try {
      final data = await _apiService.get('/talleres/especialidades/publicas');
      if (data != null) {
        setState(() {
          _especialidades = List<Map<String, dynamic>>.from(
            (data as List).map((e) => {
              'id': e['id_especialidad'],
              'nombre': e['nombre_especialidad'],
            }),
          );
          _loadingEspecialidades = false;
        });
      }
    } catch (e) {
      print('Error cargando especialidades: $e');
      setState(() => _loadingEspecialidades = false);
    }
  }

  // Cargar servicios desde API (endpoint público)
  Future<void> _cargarServicios() async {
    try {
      final data = await _apiService.get('/talleres/servicios/publicas');
      if (data != null) {
        setState(() {
          _servicios = List<Map<String, dynamic>>.from(
            (data as List).map((s) => {
              'id': s['id_servicio'],
              'nombre': s['nombre_servicio'],
            }),
          );
          _loadingServicios = false;
        });
      }
    } catch (e) {
      print('Error cargando servicios: $e');
      setState(() => _loadingServicios = false);
    }
  }

  // Iniciar/detener transcripción de audio
  Future<void> _toggleAudioTranscription() async {
    if (!_isListening) {
      // Verificar si el speech to text está disponible
      if (!_speechToText.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech to text no está disponible')),
        );
        return;
      }

      try {
        // Intentar escuchar - esto solicitará permisos automáticamente si es necesario
        setState(() => _isListening = true);
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _descripcionController.text = result.recognizedWords;
            });
          },
        );
      } catch (e) {
        print('Excepción al iniciar escucha: $e');
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      await _speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _tomarFoto() async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar Foto'),
        content: const Text('¿De dónde deseas seleccionar la foto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _capturarConCamara();
            },
            child: const Text('📷 Cámara'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _seleccionarDelGaleria();
            },
            child: const Text('🖼️ Galería'),
          ),
        ],
      ),
    );
  }

  Future<void> _capturarConCamara() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _fotoTomada = File(photo.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Foto capturada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al acceder a la cámara: $e')),
      );
    }
  }

  Future<void> _seleccionarDelGaleria() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        setState(() {
          _fotoTomada = File(photo.path);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Foto seleccionada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al acceder a la galería: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencia Vehicular'),
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del Vehículo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF6B6B), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vehículo Afectado',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.vehiculoAfectado.marca} ${widget.vehiculoAfectado.modelo}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Placa: ${widget.vehiculoAfectado.placa}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    if (widget.vehiculoAfectado.color != null)
                      Text(
                        'Color: ${widget.vehiculoAfectado.color}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Descripción del Problema
              const Text(
                'Descripción del Problema *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _descripcionController,
                      decoration: InputDecoration(
                        hintText: 'Escribe o presiona para grabar',
                        prefixIcon: const Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'La descripción es requerida';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.stop_circle : Icons.mic,
                          color: _isListening ? Colors.red : Colors.blue,
                          size: 32,
                        ),
                        onPressed: _toggleAudioTranscription,
                      ),
                      if (_isListening)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nivel de Urgencia
              const Text(
                'Nivel de Urgencia *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _nivelUrgencia,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.priority_high),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'BAJO', child: Text('Bajo')),
                  DropdownMenuItem(value: 'MEDIO', child: Text('Medio')),
                  DropdownMenuItem(value: 'ALTO', child: Text('Alto')),
                  DropdownMenuItem(value: 'CRITICO', child: Text('Crítico')),
                ],
                onChanged: (value) {
                  setState(() {
                    _nivelUrgencia = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Categoría del Incidente
              const Text(
                'Categoría del Incidente *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.warning_amber),
                  hintText: 'Selecciona una categoría',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'COLISION_VISIBLE', child: Text('Colisión Visible')),
                  DropdownMenuItem(value: 'HUMO_O_SOBRECALENTAMIENTO', child: Text('Humo o Sobrecalentamiento')),
                  DropdownMenuItem(value: 'PINCHAZO_LLANTA', child: Text('Pinchazo de Llanta')),
                  DropdownMenuItem(value: 'SIN_HALLAZGOS_CLAROS', child: Text('Sin Hallazgos Claros')),
                  DropdownMenuItem(value: 'VEHICULO_INMOVILIZADO', child: Text('Vehículo Inmovilizado')),
                ],
                onChanged: (value) {
                  setState(() {
                    _categoria = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Por favor selecciona una categoría';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Botón para Tomar Foto
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _tomarFoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar Foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    if (_fotoTomada != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Image.file(
                          _fotoTomada!,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '✓ Foto capturada',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Especialidades Necesarias
              const Text(
                'Especialidades Necesarias',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingEspecialidades)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  children: _especialidades.map((especialidad) {
                    final isSelected = _especialidadesSeleccionadas.contains(especialidad['id']);
                    return FilterChip(
                      label: Text(especialidad['nombre']),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _especialidadesSeleccionadas.add(especialidad['id']);
                          } else {
                            _especialidadesSeleccionadas.remove(especialidad['id']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),

              // Servicios Necesarios
              const Text(
                'Servicios Necesarios',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingServicios)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  children: _servicios.map((servicio) {
                    final isSelected = _serviciosSeleccionados.contains(servicio['id']);
                    return FilterChip(
                      label: Text(servicio['nombre']),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _serviciosSeleccionados.add(servicio['id']);
                          } else {
                            _serviciosSeleccionados.remove(servicio['id']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 24),

              // Ubicación con Mapa
              const Text(
                'Ubicación *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Mapa OpenStreetMap
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF5C7CFA), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(_latitud, _longitud),
                          initialZoom: 15,
                          minZoom: 3,
                          maxZoom: 19,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.emergencias.vehicular/1.0.0',
                            maxZoom: 19,
                          ),
                          // Círculo del radio de búsqueda
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: LatLng(_latitud, _longitud),
                                radius: _radioEstadio * 1000, // Radio en metros
                                useRadiusInMeter: true,
                                color: const Color(0xFF4FC3F7).withOpacity(0.15), // Celeste muy pálido
                                borderStrokeWidth: 2.5,
                                borderColor: const Color(0xFF0288D1).withOpacity(0.6), // Borde azul más visible
                              ),
                            ],
                          ),
                          // Marcador en el centro
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_latitud, _longitud),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFFF6B6B),
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Coordenadas en el centro
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'Lat: ${_latitud.toStringAsFixed(2)}°\nLng: ${_longitud.toStringAsFixed(2)}°',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5C7CFA),
                            ),
                          ),
                        ),
                      ),
                      // Botones de acción
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add, color: Color(0xFF5C7CFA)),
                                onPressed: () => setState(() {
                                  if (_radioEstadio < 100) _radioEstadio += 1;
                                }),
                                iconSize: 20,
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.remove, color: Color(0xFF5C7CFA)),
                                onPressed: () => setState(() {
                                  if (_radioEstadio > 1) _radioEstadio -= 1;
                                }),
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botones de ubicación
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _reintentarUbicacion,
                      icon: const Icon(Icons.location_on),
                      label: const Text('Obtener Ubicación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C7CFA),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Coordenadas
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Latitud',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Longitud',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Radio de Búsqueda
              const Text(
                'Radio de Búsqueda de Talleres (km)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radioEstadio,
                      min: 1,
                      max: 100,
                      divisions: 99,
                      label: '${_radioEstadio.toStringAsFixed(1)} km',
                      onChanged: (value) {
                        setState(() {
                          _radioEstadio = value.round().toDouble();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C7CFA),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_radioEstadio.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Botón Enviar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _enviarEmergencia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B6B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
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
                          'Enviar Solicitud de Emergencia',
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