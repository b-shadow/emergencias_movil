import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'calificacion_service.dart';
import 'notificacion_service.dart';
import 'offline_sync_service.dart';
import 'solicitud_service.dart';
import 'tracking_service.dart';

class OfflineStatusService {
  OfflineStatusService._();

  static final OfflineStatusService instance = OfflineStatusService._();

  final OfflineSyncService _offlineSync = OfflineSyncService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _messageClearTimer;
  Timer? _pendingRefreshTimer;
  bool _initialized = false;

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> statusMessage = ValueNotifier<String?>(null);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await refreshPendingCount();
    _pendingRefreshTimer ??=
        Timer.periodic(const Duration(seconds: 4), (_) => refreshPendingCount());
    final connectivity = Connectivity();
    final initial = await connectivity.checkConnectivity();
    await _handleConnectivityChange(initial);
    _connectivitySubscription =
        connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _messageClearTimer?.cancel();
    _pendingRefreshTimer?.cancel();
    _initialized = false;
  }

  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    final nextOnline = results.any((result) => result != ConnectivityResult.none);
    final wasOnline = isOnline.value;
    isOnline.value = nextOnline;

    if (!nextOnline) {
      await refreshPendingCount();
      _setStatusMessage('Sin conexión. Puedes seguir usando datos guardados.');
      return;
    }

    if (!wasOnline && nextOnline) {
      _setStatusMessage('Conexión recuperada. Sincronizando acciones pendientes...');
      await syncAllPending(showResult: true);
      return;
    }

    await refreshPendingCount();
  }

  Future<void> refreshPendingCount() async {
    final pending = await _offlineSync.getPendingOperations();
    pendingCount.value = pending.length;
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    return _offlineSync.getPendingOperations();
  }

  Future<void> notifyPendingChanged([String? message]) async {
    await refreshPendingCount();
    if (message != null && message.isNotEmpty) {
      _setStatusMessage(message);
    }
  }

  Future<void> syncAllPending({bool showResult = false}) async {
    if (isSyncing.value || !isOnline.value) {
      await refreshPendingCount();
      return;
    }

    final before = (await _offlineSync.getPendingOperations()).length;
    if (before == 0) {
      pendingCount.value = 0;
      if (showResult) {
        _setStatusMessage('No hay acciones pendientes por sincronizar.');
      }
      return;
    }

    isSyncing.value = true;
    try {
      await TrackingService().syncPendingOperations();
      await SolicitudService().syncPendingOperations();
      await NotificacionService().syncPendingOperations();
      await CalificacionService().syncPendingOperations();

      final after = (await _offlineSync.getPendingOperations()).length;
      pendingCount.value = after;

      if (showResult) {
        final synced = before - after;
        if (after == 0) {
          _setStatusMessage(
            synced > 0
                ? 'Sincronización completa. $synced acción(es) enviadas.'
                : 'No había acciones nuevas por sincronizar.',
          );
        } else {
          _setStatusMessage(
            'Se sincronizaron $synced acción(es). Quedan $after pendientes.',
          );
        }
      }
    } catch (_) {
      await refreshPendingCount();
      if (showResult) {
        _setStatusMessage(
          'No se pudo completar la sincronización. Se reintentará cuando vuelva la conexión.',
        );
      }
    } finally {
      isSyncing.value = false;
    }
  }

  String describeOperation(Map<String, dynamic> op) {
    final type = (op['type'] ?? '').toString();
    switch (type) {
      case 'solicitud_cancel':
        return 'Cancelar solicitud';
      case 'solicitud_update':
        return 'Actualizar solicitud';
      case 'tracking_update':
        return 'Actualizar ubicación de tracking';
      case 'tracking_accept':
        return 'Aceptar orden de recojo';
      case 'tracking_llegada_auxilio':
        return 'Marcar llegada al auxilio';
      case 'tracking_iniciar_traslado':
        return 'Iniciar traslado al taller';
      case 'tracking_llegada_taller':
        return 'Marcar llegada al taller';
      case 'notificacion_marcar_leida':
        return 'Marcar notificación como leída';
      case 'notificacion_marcar_todas':
        return 'Marcar todas las notificaciones';
      case 'calificacion_create':
        return 'Registrar calificación de atención';
      default:
        return type.isEmpty ? 'Acción pendiente' : type;
    }
  }

  String? formatQueuedAt(Map<String, dynamic> op) {
    final raw = (op['queued_at'] ?? '').toString();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _setStatusMessage(String message) {
    statusMessage.value = message;
    _messageClearTimer?.cancel();
    _messageClearTimer = Timer(const Duration(seconds: 6), () {
      if (statusMessage.value == message) {
        statusMessage.value = null;
      }
    });
  }
}
