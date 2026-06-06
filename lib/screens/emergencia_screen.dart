import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/vehiculo.dart';
import '../services/emergencia_service.dart';
import '../services/api_service.dart';
import '../widgets/theme_toggle_button.dart';

class EmergenciaScreen extends StatefulWidget {
  final Vehiculo vehiculoAfectado;

  const EmergenciaScreen({super.key, required this.vehiculoAfectado});

  @override
  State<EmergenciaScreen> createState() => _EmergenciaScreenState();
}

class _EmergenciaScreenState extends State<EmergenciaScreen> {
  static const Set<String> _categoriasDisponibles = {
    'COLISION_VISIBLE',
    'HUMO_O_SOBRECALENTAMIENTO',
    'PINCHAZO_LLANTA',
    'SIN_HALLAZGOS_CLAROS',
    'VEHICULO_INMOVILIZADO',
  };

  final EmergenciaService _emergenciaService = EmergenciaService();
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descripcionController;
  late TextEditingController _latitudController;
  late TextEditingController _longitudController;

  String _nivelUrgencia = 'MEDIO'; // BAJO, MEDIO, ALTO, CRITICO
  String?
      _categoria; // COLISION_VISIBLE, HUMO_O_SOBRECALENTAMIENTO, PINCHAZO_LLANTA, SIN_HALLAZGOS_CLAROS, VEHICULO_INMOVILIZADO
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
  final Set<String> _especialidadesSeleccionadas = {};
  final Set<String> _serviciosSeleccionados = {};
  bool _loadingEspecialidades = true;
  bool _loadingServicios = true;
  // Cámara y fotos
  File? _fotoTomada;
  Uint8List? _fotoTomadaBytes;
  bool _isProcessingImage = false;
  bool _isProcessingProblem = false;
  bool _isSuggestingSmartService = false;
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

    // Retardar la obtención de Ubicación después de que el widget está construido
    Future.delayed(const Duration(milliseconds: 100), () {
      _obtenerUbicacion();
      _cargarEspecialidades();
      _cargarServicios();
    });
  }

  Future<void> _initializeSpeechToText() async {
    try {
      bool available = await _speechToText.initialize(
        onError: (error) => debugPrint('Error Speech To Text: $error'),
        onStatus: (status) => debugPrint('Status: $status'),
      );
      if (!available) {
        debugPrint('Speech to text no disponible en este dispositivo');
      }
    } catch (e) {
      debugPrint('Error inicializando speech to text: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      // Solicitar permisos de Ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permisos de Ubicación denegados permanentemente'),
            ),
          );
        }
        return;
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Obtener Ubicación actual
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
          SnackBar(content: Text('Error al obtener Ubicación: $e')),
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
        const SnackBar(
            content: Text('Por favor completa los campos requeridos')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Generar código único para la solicitud
      final codigoSolicitud = 'SEM-${DateTime.now().millisecondsSinceEpoch}';

      final solicitudCreada = await _emergenciaService.crearSolicitudEmergencia(
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

      if (_fotoTomada != null) {
        final solicitudId = (solicitudCreada['id_solicitud'] ?? '').toString();
        if (solicitudId.isNotEmpty) {
          try {
            await _emergenciaService.subirImagenEvidenciaSolicitud(
              solicitudId: solicitudId,
              imagenArchivo: _fotoTomada!,
              descripcion: 'Evidencia adjunta desde solicitud de emergencia',
            );
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Solicitud creada, pero no se pudo adjuntar la imagen: $e',
                  ),
                  backgroundColor: const Color(0xFFF08C00),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      }

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

  Widget _buildFotoPreview() {
    if (_fotoTomadaBytes != null && kIsWeb) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _fotoTomadaBytes!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_fotoTomada != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _fotoTomada!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    }

    return const SizedBox.shrink();
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
      debugPrint('Error cargando especialidades: $e');
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
      debugPrint('Error cargando servicios: $e');
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
        debugPrint('Excepción al iniciar escucha: $e');
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
            child: const Text('Cámara'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _seleccionarDelGaleria();
            },
            child: const Text('Galería'),
          ),
        ],
      ),
    );
  }

  Future<void> _capturarConCamara() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (!mounted) return;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        setState(() {
          _fotoTomada = File(photo.path);
          _fotoTomadaBytes = bytes;
          _isProcessingImage = false;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al acceder a la Cámara: $e')),
      );
    }
  }

  Future<void> _seleccionarDelGaleria() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (!mounted) return;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        setState(() {
          _fotoTomada = File(photo.path);
          _fotoTomadaBytes = bytes;
          _isProcessingImage = false;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al acceder a la Galería: $e')),
      );
    }
  }

  String _categoriaLegible(String categoria) {
    return categoria
        .toLowerCase()
        .replaceAll('_', ' ')
        .split(' ')
        .map((palabra) => palabra.isEmpty
            ? ''
            : '${palabra[0].toUpperCase()}${palabra.substring(1)}')
        .join(' ');
  }

  Future<void> _procesarFotoConIA() async {
    if (_fotoTomada == null || _isProcessingImage) {
      return;
    }

    setState(() {
      _isProcessingImage = true;
    });

    try {
      final resultado = await _emergenciaService.procesarImagenIncidente(
        imagenArchivo: kIsWeb ? null : _fotoTomada!,
        imagenBytes: _fotoTomadaBytes,
        fileName: 'evidencia.jpg',
        evidenciaId:
            '${widget.vehiculoAfectado.id}-${DateTime.now().millisecondsSinceEpoch}',
      );

      final clasePredicha =
          (resultado['clase_predicha'] ?? '').toString().trim();
      final confianza = resultado['confianza'];
      final confianzaTexto =
          confianza is num ? ' (${(confianza * 100).toStringAsFixed(1)}%)' : '';

      if (mounted && clasePredicha.isNotEmpty) {
        final categoriaNormalizada = clasePredicha.toUpperCase();
        if (_categoriasDisponibles.contains(categoriaNormalizada)) {
          setState(() {
            _categoria = categoriaNormalizada;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Se detecto ${clasePredicha.toLowerCase()}$confianzaTexto',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2F9E44),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo procesar la imagen: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFC92A2A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
      }
    }
  }

  void _setAnalisisLoading(bool value) {
    if (!mounted) return;
    setState(() {
      _isProcessingProblem = value;
      _isSuggestingSmartService = value;
    });
  }

  List<String> _normalizarIdsSugeridos(
    dynamic rawValue,
    List<Map<String, dynamic>> catalogo,
  ) {
    if (rawValue == null) return [];

    Iterable<dynamic> items;
    if (rawValue is Iterable) {
      items = rawValue;
    } else {
      items = [rawValue];
    }

    final ids = <String>[];
    for (final item in items) {
      if (item == null) continue;
      if (item is String) {
        final value = item.trim();
        if (value.isNotEmpty) {
          final matchPorId = catalogo.where(
            (entry) => entry['id']?.toString() == value,
          );
          if (matchPorId.isNotEmpty) {
            ids.add(matchPorId.first['id']?.toString() ?? value);
            continue;
          }

          final matchPorNombre = catalogo.where(
            (entry) => entry['nombre']?.toString().toLowerCase() == value.toLowerCase(),
          );
          if (matchPorNombre.isNotEmpty) {
            ids.add(matchPorNombre.first['id']?.toString() ?? value);
            continue;
          }

          ids.add(value);
        }
        continue;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final value = (map['id'] ??
                map['id_servicio'] ??
                map['id_especialidad'] ??
                map['value'] ??
                map['nombre'] ??
                map['nombre_servicio'] ??
                map['nombre_especialidad'])
            ?.toString()
            .trim();
        if (value != null && value.isNotEmpty) {
          final matchPorId = catalogo.where(
            (entry) => entry['id']?.toString() == value,
          );
          if (matchPorId.isNotEmpty) {
            ids.add(matchPorId.first['id']?.toString() ?? value);
            continue;
          }

          final matchPorNombre = catalogo.where(
            (entry) => entry['nombre']?.toString().toLowerCase() == value.toLowerCase(),
          );
          if (matchPorNombre.isNotEmpty) {
            ids.add(matchPorNombre.first['id']?.toString() ?? value);
            continue;
          }

          ids.add(value);
        }
        continue;
      }
      final value = item.toString().trim();
      if (value.isNotEmpty) ids.add(value);
    }

    return ids.toSet().toList();
  }

  String? _nombreEspecialidadPorId(String id) {
    final match = _especialidades.cast<Map<String, dynamic>>().where(
          (item) => item['id']?.toString() == id,
        );
    if (match.isEmpty) return null;
    return match.first['nombre']?.toString();
  }

  String? _nombreServicioPorId(String id) {
    final match = _servicios.cast<Map<String, dynamic>>().where(
          (item) => item['id']?.toString() == id,
        );
    if (match.isEmpty) return null;
    return match.first['nombre']?.toString();
  }

  String _capitalizarEtiqueta(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    return normalized.isEmpty
        ? value
        : normalized
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
  }

  Future<void> _aplicarAnalisisInteligente({required String texto}) async {
    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero describe el problema para poder analizarlo'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFC92A2A),
        ),
      );
      return;
    }

    if (_isProcessingProblem || _isSuggestingSmartService) return;

    _setAnalisisLoading(true);

    try {
      final problema = await _emergenciaService.procesarProblemaTexto(
        textoProblema: texto,
        idVehiculo: widget.vehiculoAfectado.id,
        categoriaIncidente: _categoria,
      );

      final nivel = [
        problema['nivel_urgencia'],
        problema['prioridad'],
      ]
          .map((value) => value?.toString().toUpperCase().trim() ?? '')
          .firstWhere(
            (value) => const {'BAJO', 'MEDIO', 'ALTO', 'CRITICO'}.contains(value),
            orElse: () => '',
          );
      if (nivel.isNotEmpty) {
        _nivelUrgencia = nivel;
      }

      final categoriaDetectada = [
        problema['categoria_incidente'],
        problema['categoria'],
      ]
          .map((value) => value?.toString().toUpperCase().trim() ?? '')
          .firstWhere(
            (value) => _categoriasDisponibles.contains(value),
            orElse: () => '',
          );
      if (categoriaDetectada.isNotEmpty) {
        _categoria = categoriaDetectada;
      }

      final especialidadesSugeridas = <String>{
        ..._normalizarIdsSugeridos(
          problema['especialidades_sugeridas'] ??
              problema['especialidad_sugerida'] ??
              problema['ids_especialidades_sugeridas'] ??
              problema['id_especialidad_sugerida'],
          _especialidades,
        ),
      };

      final serviciosSugeridos = <String>{
        ..._normalizarIdsSugeridos(
          problema['servicios_sugeridos'] ??
              problema['servicio_sugerido'] ??
              problema['ids_servicios_sugeridos'] ??
              problema['id_servicio_sugerido'],
          _servicios,
        ),
      };

      if (especialidadesSugeridas.isNotEmpty) {
        _especialidadesSeleccionadas.addAll(especialidadesSugeridas);
      }
      if (serviciosSugeridos.isNotEmpty) {
        _serviciosSeleccionados.addAll(serviciosSugeridos);
      }

      final motivo = [
        problema['resumen'],
        problema['motivo'],
        problema['explicacion'],
      ]
          .map((value) => value?.toString().trim() ?? '')
          .firstWhere((value) => value.isNotEmpty, orElse: () => '');

      final especialidadesTexto = especialidadesSugeridas
          .map((id) => _nombreEspecialidadPorId(id) ?? id)
          .toList();
      final serviciosTexto = serviciosSugeridos
          .map((id) => _nombreServicioPorId(id) ?? id)
          .toList();

      final detalles = <String>[];
      if (nivel.isNotEmpty) {
        detalles.add('urgencia ${_capitalizarEtiqueta(nivel)}');
      }
      if (_categoria != null && _categoria!.isNotEmpty) {
        detalles.add('categoría ${_categoriaLegible(_categoria!)}');
      }
      if (especialidadesTexto.isNotEmpty) {
        detalles.add('especialidad ${especialidadesTexto.join(', ')}');
      }
      if (serviciosTexto.isNotEmpty) {
        detalles.add('servicios ${serviciosTexto.join(', ')}');
      }

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detalles.isEmpty
                  ? 'Análisis completado'
                  : 'Identificado: ${detalles.join(', ')}${motivo.isNotEmpty ? '. $motivo' : ''}',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            backgroundColor: const Color(0xFF0B7285),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo analizar el problema: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFC92A2A),
          ),
        );
      }
    } finally {
      if (mounted) {
        _setAnalisisLoading(false);
      }
    }
  }

  Future<void> _procesarProblemaConIA() async {
    await _aplicarAnalisisInteligente(
      texto: _descripcionController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1117) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 72,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Emergencia Vehicular',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF6B6B), Color(0xFFFF4B4F)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const ThemeToggleButton(),
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: isDark ? const Color(0xFF181B24) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFFF5A5F), width: 1.7),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          expansionTileTheme: ExpansionTileThemeData(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            collapsedShape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            iconColor: cs.onSurface.withValues(alpha: 0.8),
            collapsedIconColor: cs.onSurface.withValues(alpha: 0.8),
            textColor: cs.onSurface,
            collapsedTextColor: cs.onSurface,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // información del Vehículo
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF322327)
                        : const Color(0xFFFFEDEE),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFF8787)
                          : const Color(0xFFFF6B6B),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5A5F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_car_filled,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vehículo Afectado',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B6B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${widget.vehiculoAfectado.marca} ${widget.vehiculoAfectado.modelo}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1F1F1F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Placa: ${widget.vehiculoAfectado.placa}',
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF2B2B2B),
                              ),
                            ),
                            if (widget.vehiculoAfectado.color != null)
                              Text(
                                'Color: ${widget.vehiculoAfectado.color}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                          ],
                        ),
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
                            return 'La Descripción es requerida';
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isProcessingProblem ? null : _procesarProblemaConIA,
                    icon: _isProcessingProblem
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.psychology_alt_outlined),
                    label: Text(
                      _isProcessingProblem
                          ? 'Procesando problema...'
                          : 'Procesar problema',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5F3DC4),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
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
                  initialValue: _nivelUrgencia,
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
                  initialValue: _categoria,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.warning_amber),
                    hintText: 'Selecciona una Categoría',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'COLISION_VISIBLE',
                        child: Text('Colisión Visible')),
                    DropdownMenuItem(
                        value: 'HUMO_O_SOBRECALENTAMIENTO',
                        child: Text('Humo o Sobrecalentamiento')),
                    DropdownMenuItem(
                        value: 'PINCHAZO_LLANTA',
                        child: Text('Pinchazo de Llanta')),
                    DropdownMenuItem(
                        value: 'SIN_HALLAZGOS_CLAROS',
                        child: Text('Sin Hallazgos Claros')),
                    DropdownMenuItem(
                        value: 'VEHICULO_INMOVILIZADO',
                        child: Text('Vehículo Inmovilizado')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _categoria = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Por favor selecciona una Categoría';
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
                        label: const Text('Tomar o Seleccionar Foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      if (_fotoTomada != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildFotoPreview(),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Foto lista para análisis IA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2B8A3E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed:
                              _isProcessingImage ? null : _procesarFotoConIA,
                          icon: _isProcessingImage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _isProcessingImage
                                ? 'Procesando...'
                                : 'Procesar con IA',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B7285),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                        if (_categoria != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Categoría detectada: ${_categoriaLegible(_categoria!)}',
                              style: const TextStyle(
                                color: Color(0xFF0B7285),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(
                        'Seleccionar especialidades (${_especialidadesSeleccionadas.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _especialidades.map((especialidad) {
                            final isSelected = _especialidadesSeleccionadas
                                .contains(especialidad['id']);
                            return FilterChip(
                              label: Text(especialidad['nombre']),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _especialidadesSeleccionadas
                                        .add(especialidad['id']);
                                  } else {
                                    _especialidadesSeleccionadas
                                        .remove(especialidad['id']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (_especialidadesSeleccionadas.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _especialidades
                        .where((especialidad) => _especialidadesSeleccionadas
                            .contains(especialidad['id']))
                        .map(
                          (especialidad) => Chip(
                            label: Text(especialidad['nombre']),
                            backgroundColor: const Color(0xFFD3F9D8),
                            side: const BorderSide(color: Color(0xFF37B24D)),
                            labelStyle: const TextStyle(
                              color: Color(0xFF2B8A3E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(
                        'Seleccionar servicios (${_serviciosSeleccionados.length})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _servicios.map((servicio) {
                            final isSelected = _serviciosSeleccionados
                                .contains(servicio['id']);
                            return FilterChip(
                              label: Text(servicio['nombre']),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _serviciosSeleccionados.add(servicio['id']);
                                  } else {
                                    _serviciosSeleccionados
                                        .remove(servicio['id']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                if (_serviciosSeleccionados.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _servicios
                        .where((servicio) =>
                            _serviciosSeleccionados.contains(servicio['id']))
                        .map(
                          (servicio) => Chip(
                            label: Text(servicio['nombre']),
                            backgroundColor: const Color(0xFFD3F9D8),
                            side: const BorderSide(color: Color(0xFF37B24D)),
                            labelStyle: const TextStyle(
                              color: Color(0xFF2B8A3E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
                    border:
                        Border.all(color: const Color(0xFF5C7CFA), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
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
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.emergencias.vehicular/1.0.0',
                              maxZoom: 19,
                            ),
                            // Círculo del radio de Búsqueda
                            CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: LatLng(_latitud, _longitud),
                                  radius:
                                      _radioEstadio * 1000, // Radio en metros
                                  useRadiusInMeter: true,
                                  color: const Color(0xFF4FC3F7)
                                      .withValues(alpha: 0.15), // Celeste muy pálido
                                  borderStrokeWidth: 2.5,
                                  borderColor: const Color(0xFF0288D1)
                                      .withValues(alpha: 
                                          0.6), // Borde azul más visible
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
                                  color: Colors.black.withValues(alpha: 0.2),
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
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add,
                                      color: Color(0xFF5C7CFA)),
                                  onPressed: () => setState(() {
                                    if (_radioEstadio < 100) _radioEstadio += 1;
                                  }),
                                  iconSize: 20,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.remove,
                                      color: Color(0xFF5C7CFA)),
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

                // Botones de Ubicación
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
      ),
    );
  }
}




