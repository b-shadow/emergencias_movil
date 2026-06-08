import 'package:flutter/material.dart';

import '../services/offline_status_service.dart';

class OfflineSyncButton extends StatelessWidget {
  const OfflineSyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = OfflineStatusService.instance;

    return ValueListenableBuilder<int>(
      valueListenable: service.pendingCount,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: service.isSyncing,
          builder: (context, isSyncing, __) {
            return ValueListenableBuilder<bool>(
              valueListenable: service.isOnline,
              builder: (context, isOnline, ___) {
                final cs = Theme.of(context).colorScheme;
                final hasPending = pendingCount > 0;
                final accentColor = !isOnline
                    ? const Color(0xFFF59E0B)
                    : hasPending
                        ? const Color(0xFF2563EB)
                        : cs.onSurface.withValues(alpha: 0.7);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPendingSheet(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(
                                alpha: hasPending || !isOnline ? 0.34 : 0.18,
                              ),
                            ),
                          ),
                          child: isSyncing
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                )
                              : Icon(
                                  !isOnline
                                      ? Icons.cloud_off_rounded
                                      : hasPending
                                          ? Icons.cloud_sync_rounded
                                          : Icons.cloud_done_rounded,
                                  color: accentColor,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                    if (hasPending)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5A5F),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            pendingCount > 99 ? '99+' : '$pendingCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
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
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pendientes por sincronizar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pending.isEmpty
                                ? 'No hay acciones pendientes en este momento.'
                                : 'Hay ${pending.length} accion(es) esperando conexión o sincronización.',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainerHighest
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: pending.isEmpty
                      ? Column(
                          children: [
                            Icon(
                              Icons.inbox_rounded,
                              size: 34,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Todo sincronizado',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cuando haya acciones offline o pendientes, aparecerán aquí.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
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
                                  child: Icon(
                                    Icons.schedule_send_rounded,
                                    color: cs.primary,
                                  ),
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
                ),
                const SizedBox(height: 14),
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
                        onPressed: pending.isEmpty
                            ? null
                            : () async {
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
