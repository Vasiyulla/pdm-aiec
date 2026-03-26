// ============================================================
//  logs_screen.dart  —  Event log viewer
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_shell.dart';
//import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filter = 'ALL';
  final _filters = ['ALL', 'MOTOR', 'CONNECT', 'ERROR', 'CONFIG'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotorProvider>().loadLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorProvider>();
    final logs = motor.eventLogs.where((l) {
      if (_filter == 'ALL') return true;
      return (l['level'] as String?)?.contains(_filter) == true ||
          (l['message'] as String?)?.contains(_filter) == true;
    }).toList();

    return AppShell(
      currentRoute: AppRouter.logs,
      child: Column(
        children: [
          // Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: AppColors.bg900,
              border: Border(bottom: BorderSide(color: AppColors.bg600)),
            ),
            child: Row(
              children: [
                Text('Event Log',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 20),
                // Filters
                ..._filters.map((f) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: _filter == f
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    )),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textSecondary),
                  onPressed: motor.loadLogs,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Log list
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text('No log entries',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textMuted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final entry = logs[i];
                      final level = entry['level'] as String? ?? 'INFO';
                      final msg = entry['message'] as String? ?? '';
                      final ts = (entry['timestamp'] as num?)?.toDouble() ?? 0;
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                          (ts * 1000).toInt());
                      final timeStr = DateFormat('HH:mm:ss').format(dt);
                      final dateStr = DateFormat('dd MMM').format(dt);
                      final color = _levelColor(level);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.bg700,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            // Level badge
                            Container(
                              width: 64,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                level,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Timestamp
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(dateStr,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    )),
                              ],
                            ),
                            const SizedBox(width: 16),
                            // Message
                            Expanded(
                              child: Text(
                                msg,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(String level) {
    if (level.contains('ERROR')) return AppColors.accentRed;
    if (level.contains('WARN')) return AppColors.accentAmber;
    if (level.contains('MOTOR')) return AppColors.primary;
    if (level.contains('CONNECT')) return AppColors.accentGreen;
    return AppColors.textSecondary;
  }
}
