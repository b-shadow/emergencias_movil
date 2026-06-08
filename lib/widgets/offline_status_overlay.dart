import 'package:flutter/material.dart';

import '../services/offline_status_service.dart';

class OfflineStatusOverlay extends StatelessWidget {
  const OfflineStatusOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final service = OfflineStatusService.instance;

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: ValueListenableBuilder<bool>(
              valueListenable: service.isOnline,
              builder: (context, isOnline, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: service.pendingCount,
                  builder: (context, pendingCount, __) {
                    return ValueListenableBuilder<bool>(
                      valueListenable: service.isSyncing,
                      builder: (context, isSyncing, ___) {
                        return ValueListenableBuilder<String?>(
                          valueListenable: service.statusMessage,
                          builder: (context, message, ____) {
                            final visible = !isOnline || pendingCount > 0 || isSyncing || (message?.isNotEmpty ?? false);
                            if (!visible) return const SizedBox.shrink();

                            final cs = Theme.of(context).colorScheme;
                            final tone = !isOnline
                                ? const _Tone(
                                    background: Color(0xFFFEE2E2),
                                    border: Color(0xFFFCA5A5),
                                    foreground: Color(0xFF991B1B),
                                    icon: Icons.cloud_off_rounded,
                                  )
                                : isSyncing
                                    ? const _Tone(
                                        background: Color(0xFFDBEAFE),
                                        border: Color(0xFF93C5FD),
                                        foreground: Color(0xFF1D4ED8),
                                        icon: Icons.sync_rounded,
                                      )
                                    : pendingCount > 0
                                        ? const _Tone(
                                            background: Color(0xFFFEF3C7),
                                            border: Color(0xFFFCD34D),
                                            foreground: Color(0xFF92400E),
                                            icon: Icons.schedule_send_rounded,
                                          )
                                        : const _Tone(
                                            background: Color(0xFFDCFCE7),
                                            border: Color(0xFF86EFAC),
                                            foreground: Color(0xFF166534),
                                            icon: Icons.cloud_done_rounded,
                                          );

                            final subtitle = message ??
                                (!isOnline
                                    ? 'Trabajando sin conexión. Las acciones nuevas quedarán pendientes.'
                                    : pendingCount > 0
                                        ? 'Hay $pendingCount acción(es) pendientes por sincronizar.'
                                        : 'Sincronización al día.');

                            return Material(
                              color: Colors.transparent,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 720),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? cs.surfaceContainerHighest
                                      : tone.background,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? cs.outlineVariant
                                        : tone.border,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      tone.icon,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? cs.primary
                                          : tone.foreground,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            !isOnline
                                                ? 'Modo offline activo'
                                                : isSyncing
                                                    ? 'Sincronizando acciones'
                                                    : pendingCount > 0
                                                        ? 'Acciones pendientes'
                                                        : 'Sincronización completa',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? cs.onSurface
                                                  : tone.foreground,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            subtitle,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? cs.onSurface.withValues(alpha: 0.78)
                                                  : tone.foreground.withValues(alpha: 0.92),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () => _showPendingSheet(context),
                                      child: const Text('Ver'),
                                    ),
                                    if (isOnline && pendingCount > 0 && !isSyncing)
                                      ElevatedButton(
                                        onPressed: () => service.syncAllPending(showResult: true),
                                        child: const Text('Sincronizar'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPendingSheet(BuildContext context) async {
    final service = OfflineStatusService.instance;
    final pending = await service.getPendingOperations();
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync_rounded),
                    const SizedBox(width: 10),
                    Text(
                      'Acciones pendientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No hay acciones pendientes por sincronizar.',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (context, index) {
                        final op = pending[index];
                        final queuedAt = service.formatQueuedAt(op);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.schedule_send_rounded, color: cs.primary),
                          ),
                          title: Text(
                            service.describeOperation(op),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            queuedAt == null
                                ? 'Pendiente de sincronización'
                                : 'Pendiente desde $queuedAt',
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await service.syncAllPending(showResult: true);
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        },
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('Sincronizar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tone {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const _Tone({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });
}
