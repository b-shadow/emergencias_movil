import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/solicitud.dart';
import '../services/solicitud_service.dart';
import '../services/api_service.dart';

class EditarSolicitudScreen extends StatefulWidget {
  final Solicitud solicitud;
  final VoidCallback onActualizar;

  const EditarSolicitudScreen({
    Key? key,
    required this.solicitud,
    required this.onActualizar,
  }) : super(key: key);

  @override
  State<EditarSolicitudScreen> createState() => _EditarSolicitudScreenState();
}

class _EditarSolicitudScreenState extends State<EditarSolicitudScreen> {
  final SolicitudService _solicitudService = SolicitudService();
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descripcionController;
  late TextEditingController _latitudController;
  late TextEditingController _longitudController;

  String _nivelUrgencia = 'MEDIO';
  String? _categoria;
  double _radioEstadio = 5.0;
  double _latitud = -17.4;
  double _longitud = -66.1;
  bool _isSaving = false;
  late MapController _mapController;

  // Speech-to-text
  late stt.SpeechToText _speechToText;
  bool _isListeningAudio = false;

  List<Map<String, dynamic>> _especialidades = [];
  List<Map<String, dynamic>> _servicios = [];
  Set<String> _especialidadesSeleccionadas = {};
  Set<String> _serviciosSeleccionados = {};
  bool _loadingEspecialidades = true;
  bool _loadingServicios = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Pre-llenar con datos existentes
    _descripcionController = TextEditingController(text: widget.solicitud.descripcion);
    _latitudController = TextEditingController(text: widget.solicitud.latitud?.toString() ?? '');
    _longitudController = TextEditingController(text: widget.solicitud.longitud?.toString() ?? '');
    
    _nivelUrgencia = widget.solicitud.nivelUrgencia;
    _categoria = widget.solicitud.categoria;
    _radioEstadio = widget.solicitud.radioEstadio;
    _latitud = widget.solicitud.latitud ?? -17.7693;
    _longitud = widget.solicitud.longitud ?? -63.1078;
    _especialidadesSeleccionadas = Set<String>.from(widget.solicitud.especialidadesRequeridas);
    _serviciosSeleccionados = Set<String>.from(widget.solicitud.serviciosRequeridos);

    // Speech-to-text
    _speechToText = stt.SpeechToText();
    _initializeSpeechToText();

    Future.delayed(const Duration(milliseconds: 100), () {
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

  Future<void> _cargarEspecialidades() async {
    try {
      final data = await _apiService.get('/talleres/especialidades/publicas');
      if (data != null) {
        setState(() {
          _especialidades = List<Map<String, dynamic>>.from(
            (data as List).map((e) => {
              'id_especialidad': e['id_especialidad'],
              'nombre_especialidad': e['nombre_especialidad'],
            }),
          );
          _loadingEspecialidades = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar especialidades: $e')),
        );
      }
    }
  }

  Future<void> _cargarServicios() async {
    try {
      final data = await _apiService.get('/talleres/servicios/publicas');
      if (data != null) {
        setState(() {
          _servicios = List<Map<String, dynamic>>.from(
            (data as List).map((s) => {
              'id_servicio': s['id_servicio'],
              'nombre_servicio': s['nombre_servicio'],
            }),
          );
          _loadingServicios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar servicios: $e')),
        );
      }
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Mapear nombres de especialidades a IDs
      final idEspecialidades = _especialidades
          .where((esp) => _especialidadesSeleccionadas.contains(esp['nombre_especialidad']))
          .map((esp) => esp['id_especialidad'] as String)
          .toList();

      // Mapear nombres de servicios a IDs
      final idServicios = _servicios
          .where((serv) => _serviciosSeleccionados.contains(serv['nombre_servicio']))
          .map((serv) => serv['id_servicio'] as String)
          .toList();

      await _solicitudService.actualizarSolicitud(
        widget.solicitud.idSolicitud,
        descripcion: _descripcionController.text,
        nivelUrgencia: _nivelUrgencia,
        radioEstadio: _radioEstadio,
        categoria: _categoria,
        idEspecialidades: idEspecialidades,
        idServicios: idServicios,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Solicitud actualizada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onActualizar();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleAudioTranscription() async {
    if (!_isListeningAudio) {
      // Verificar si el speech to text está disponible
      if (!_speechToText.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech to text no está disponible')),
        );
        return;
      }

      try {
        // Intentar escuchar - esto solicitará permisos automáticamente si es necesario
        setState(() => _isListeningAudio = true);
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _descripcionController.text = result.recognizedWords;
              if (result.finalResult) {
                _isListeningAudio = false;
              }
            });
          },
        );
      } catch (e) {
        print('Excepción al iniciar escucha: $e');
        setState(() => _isListeningAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } else {
      _speechToText.stop();
      setState(() => _isListeningAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = LatLng(_latitud, _longitud);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.redAccent,
        title: const Text('Editar Solicitud'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Código y estado
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Código: ${widget.solicitud.codigoSolicitud}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estado: ${widget.solicitud.estado}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Especialidades
              const Text(
                'Especialidades Necesarias',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_loadingEspecialidades)
                const Center(child: CircularProgressIndicator())
              else if (_especialidades.isEmpty)
                const Text('No hay especialidades disponibles')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _especialidades
                      .map((esp) => FilterChip(
                            label: Text(esp['nombre_especialidad']),
                            selected: _especialidadesSeleccionadas.contains(esp['nombre_especialidad']),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _especialidadesSeleccionadas.add(esp['nombre_especialidad']);
                                } else {
                                  _especialidadesSeleccionadas.remove(esp['nombre_especialidad']);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),

              // Servicios
              const Text(
                'Servicios Necesarios',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_loadingServicios)
                const Center(child: CircularProgressIndicator())
              else if (_servicios.isEmpty)
                const Text('No hay servicios disponibles')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _servicios
                      .map((serv) => FilterChip(
                            label: Text(serv['nombre_servicio']),
                            selected: _serviciosSeleccionados.contains(serv['nombre_servicio']),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _serviciosSeleccionados.add(serv['nombre_servicio']);
                                } else {
                                  _serviciosSeleccionados.remove(serv['nombre_servicio']);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),

              // Descripción y voz
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _descripcionController,
                      decoration: InputDecoration(
                        hintText: 'Describe el problema',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) => value?.isEmpty ?? true ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: _isListeningAudio ? Colors.red : Colors.blue,
                        onPressed: _toggleAudioTranscription,
                        child: Icon(
                          _isListeningAudio ? Icons.stop : Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isListeningAudio ? 'Escuchando...' : 'Voz',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nivel de urgencia
              const Text(
                'Nivel de Urgencia',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _nivelUrgencia,
                items: ['BAJO', 'MEDIO', 'ALTO', 'CRITICO']
                    .map((nivel) => DropdownMenuItem(
                          value: nivel,
                          child: Text(nivel),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _nivelUrgencia = value ?? 'MEDIO'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.priority_high),
                ),
              ),
              const SizedBox(height: 16),

              // Categoría
              const Text(
                'Categoría de Incidente',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _categoria,
                items: [
                  'COLISION_VISIBLE',
                  'HUMO_O_SOBRECALENTAMIENTO',
                  'PINCHAZO_LLANTA',
                  'SIN_HALLAZGOS_CLAROS',
                  'VEHICULO_INMOVILIZADO'
                ]
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (value) => setState(() => _categoria = value),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.warning_amber),
                ),
              ),
              const SizedBox(height: 16),

              // Mapa con radio de búsqueda
              const Text(
                'Ubicación *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 300,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: location,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.emergencias.vehicular/1.0.0',
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: location,
                            radius: _radioEstadio * 1000, // Radio en metros
                            useRadiusInMeter: true,
                            color: Colors.blue.withOpacity(0.3),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: location,
                            width: 40,
                            height: 40,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Radio de búsqueda con slider
              const Text(
                'Radio de Búsqueda de Talleres (km)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _radioEstadio,
                      min: 0.5,
                      max: 100,
                      divisions: 199,
                      label: '${_radioEstadio.toStringAsFixed(1)} km',
                      onChanged: (value) {
                        setState(() => _radioEstadio = value);
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_radioEstadio.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Botón guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _guardarCambios,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text(
                          'Guardar Cambios',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _latitudController.dispose();
    _longitudController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}
