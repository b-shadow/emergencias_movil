import 'package:flutter/material.dart';
import '../services/tracking_service.dart';
import 'trabajador_tracking_screen.dart';

class TrabajadorOrdenesScreen extends StatefulWidget {
  const TrabajadorOrdenesScreen({super.key});

  @override
  State<TrabajadorOrdenesScreen> createState() =>
      _TrabajadorOrdenesScreenState();
}

class _TrabajadorOrdenesScreenState extends State<TrabajadorOrdenesScreen> {
  final TrackingService _trackingService = TrackingService();
  bool _loading = true;
  List<dynamic> _ordenes = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final rows =
          await _trackingService.obtenerMisOrdenes(incluirHistorial: true);
      if (!mounted) return;
      setState(() {
        _ordenes = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'PENDIENTE_ACEPTACION':
        return Colors.orange;
      case 'ACEPTADA':
      case 'EN_CAMINO_RECOJO':
        return Colors.blue;
      case 'LLEGADA_AUXILIO':
        return Colors.deepPurple;
      case 'EN_CAMINO_TALLER':
        return Colors.teal;
      case 'FINALIZADA':
        return Colors.green;
      case 'CANCELADA':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'PENDIENTE_ACEPTACION':
        return 'Pendiente';
      case 'ACEPTADA':
        return 'Aceptada';
      case 'EN_CAMINO_RECOJO':
        return 'En camino al auxilio';
      case 'LLEGADA_AUXILIO':
        return 'Llegó al auxilio';
      case 'EN_CAMINO_TALLER':
        return 'Traslado al taller';
      case 'FINALIZADA':
        return 'Finalizada';
      case 'CANCELADA':
        return 'Cancelada';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Órdenes de recojo'),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ordenes.isEmpty
              ? const Center(child: Text('No tienes órdenes registradas'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ordenes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final orden =
                          Map<String, dynamic>.from(_ordenes[index] as Map);
                      final estado = (orden['estado_orden'] ?? '').toString();
                      final codigo =
                          (orden['codigo_solicitud'] ?? 'Orden ${index + 1}')
                              .toString();
                      final cliente =
                          (orden['cliente_nombre'] ?? 'Cliente no disponible')
                              .toString();
                      final fechaAsignacion = DateTime.tryParse(
                          (orden['fecha_asignacion'] ?? '').toString());

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrabajadorTrackingScreen(ordenInicial: orden),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: _estadoColor(estado)
                                    .withValues(alpha: 0.35)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
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
                                      codigo,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _estadoColor(estado)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _estadoLabel(estado),
                                      style: TextStyle(
                                        color: _estadoColor(estado),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cliente: $cliente',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.72),
                                ),
                              ),
                              if (fechaAsignacion != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Asignada: ${fechaAsignacion.toLocal()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.58),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.open_in_new,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Abrir detalle',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
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
    );
  }
}
