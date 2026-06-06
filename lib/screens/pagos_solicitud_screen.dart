import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import '../services/pago_service.dart';

class PagosSolicitudScreen extends StatefulWidget {
  final String idSolicitud;

  const PagosSolicitudScreen({super.key, required this.idSolicitud});

  @override
  State<PagosSolicitudScreen> createState() => _PagosSolicitudScreenState();
}

class _PagosSolicitudScreenState extends State<PagosSolicitudScreen> {
  final PagoService _pagoService = PagoService();
  final TextEditingController _montoCtrl = TextEditingController();

  bool _loading = true;
  bool _paying = false;
  Map<String, dynamic>? _resumen;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final r = await _pagoService.obtenerResumen(widget.idSolicitud);
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando pagos: $e')),
      );
    }
  }

  Future<void> _pagar(double monto) async {
    if (monto <= 0) return;
    setState(() => _paying = true);
    try {
      final intent = await _pagoService.crearPaymentIntent(widget.idSolicitud, monto);
      final clientSecret = (intent['client_secret'] ?? '').toString();
      final paymentIntentId = (intent['payment_intent_id'] ?? '').toString();
      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        throw Exception('Stripe no devolvió datos completos del pago');
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Asistencia Vehicular',
          paymentIntentClientSecret: clientSecret,
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      await _pagoService.confirmarPago(widget.idSolicitud, paymentIntentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago confirmado correctamente')),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar el pago: $e')),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ((_resumen?['total_exigible'] ?? 0) as num).toDouble();
    final pagado = ((_resumen?['total_pagado'] ?? 0) as num).toDouble();
    final saldo = ((_resumen?['saldo_pendiente'] ?? 0) as num).toDouble();
    final estadoPago = (_resumen?['estado_pago'] ?? 'PENDIENTE').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Pagos de Solicitud')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estado de pago: $estadoPago', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('Total exigible: USD ${total.toStringAsFixed(2)}'),
                          Text('Total pagado: USD ${pagado.toStringAsFixed(2)}'),
                          Text('Saldo pendiente: USD ${saldo.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _montoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto a pagar (USD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: (_paying || saldo <= 0)
                        ? null
                        : () {
                            final v = double.tryParse(_montoCtrl.text.trim());
                            if (v == null || v <= 0) return;
                            _pagar(v);
                          },
                    icon: const Icon(Icons.payments),
                    label: Text(_paying ? 'Procesando...' : 'Pagar monto ingresado'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: (_paying || saldo <= 0) ? null : () => _pagar(saldo),
                    child: const Text('Pagar saldo total'),
                  ),
                ],
              ),
            ),
    );
  }
}
