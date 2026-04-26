import 'package:flutter/material.dart';
import '../models/solicitud.dart';
import '../services/solicitud_service.dart';
import 'detalle_solicitud_screen.dart';
import '../widgets/theme_toggle_button.dart';

class MisSolicitudesScreen extends StatefulWidget {
  const MisSolicitudesScreen({Key? key}) : super(key: key);

  @override
  State<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends State<MisSolicitudesScreen> {
  final SolicitudService _solicitudService = SolicitudService();
  List<Solicitud> _solicitudes = [];
  bool _isLoading = true;
  String _ordenamiento = 'reciente'; // 'reciente' o 'antiguo'

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  Future<void> _cargarSolicitudes() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final solicitudes = await _solicitudService.obtenerSolicitudes();
      setState(() {
        _solicitudes = solicitudes;
        _ordenarSolicitudes();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar solicitudes: $e')),
      );
    }
  }

  void _ordenarSolicitudes() {
    if (_ordenamiento == 'reciente') {
      _solicitudes.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    } else {
      _solicitudes.sort((a, b) => a.fechaCreacion.compareTo(b.fechaCreacion));
    }
  }

  void _cambiarOrdenamiento(String valor) {
    setState(() {
      _ordenamiento = valor;
      _ordenarSolicitudes();
    });
  }

  String _obtenerEstadoTexto(String estado) {
    switch (estado) {
      case 'REGISTRADA':
        return 'Registrada';
      case 'EN_BUSQUEDA':
        return 'En búsqueda';
      case 'ASIGNADA':
        return 'Asignada';
      case 'EN_ATENCION':
        return 'En atención';
      case 'ATENDIDA':
        return 'Atendida';
      case 'CANCELADA':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'REGISTRADA':
      case 'EN_BUSQUEDA':
        return const Color(0xFF1D9BF0);
      case 'ASIGNADA':
      case 'EN_ATENCION':
        return const Color(0xFFF59E0B);
      case 'ATENDIDA':
        return const Color(0xFF22C55E);
      case 'CANCELADA':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1117) : const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
        backgroundColor: const Color(0xFFFF5A5F),
        foregroundColor: Colors.white,
        actions: const [ThemeToggleButton()],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181B24) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Text(
                  'Ordenar por:',
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _ordenamiento,
                      items: const [
                        DropdownMenuItem(
                            value: 'reciente', child: Text('Más reciente')),
                        DropdownMenuItem(
                            value: 'antiguo', child: Text('Más antiguo')),
                      ],
                      onChanged: (valor) {
                        if (valor != null) {
                          _cambiarOrdenamiento(valor);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _solicitudes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_rounded,
                                size: 62,
                                color: cs.onSurface.withOpacity(0.25)),
                            const SizedBox(height: 14),
                            Text(
                              'No hay solicitudes registradas',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.65),
                                  fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarSolicitudes,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                          itemCount: _solicitudes.length,
                          itemBuilder: (context, index) {
                            final solicitud = _solicitudes[index];
                            final estadoColor =
                                _getColorEstado(solicitud.estado);
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DetalleSolicitudScreen(
                                      solicitud: solicitud,
                                      onActualizar: _cargarSolicitudes,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF181B24)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: estadoColor.withOpacity(0.35),
                                      width: 1.3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(isDark ? 0.24 : 0.07),
                                      blurRadius: 12,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            solicitud.codigoSolicitud,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 29,
                                              letterSpacing: 0.4,
                                              color: cs.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: estadoColor,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _obtenerEstadoTexto(
                                                solicitud.estado),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.directions_car_outlined,
                                          color: cs.onSurface.withOpacity(0.7),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            solicitud.vehiculo,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: cs.onSurface
                                                  .withOpacity(0.78),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.priority_high_rounded,
                                              size: 18,
                                              color: solicitud.nivelUrgencia ==
                                                      'ALTO'
                                                  ? const Color(0xFFF59E0B)
                                                  : const Color(0xFF60A5FA),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              solicitud.nivelUrgencia,
                                              style: TextStyle(
                                                color: cs.onSurface
                                                    .withOpacity(0.75),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          _formatearFecha(
                                              solicitud.fechaCreacion),
                                          style: TextStyle(
                                            color:
                                                cs.onSurface.withOpacity(0.52),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
