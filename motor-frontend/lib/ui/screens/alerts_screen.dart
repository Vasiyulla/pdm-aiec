// ============================================================
//  alerts_screen.dart  —  Alert management
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/motor_models.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotorProvider>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorProvider>();
    final auth = context.watch<AuthProvider>();

    return AppShell(
      currentRoute: AppRouter.alerts,
      child: Column(
        children: [
          // Header
          Container(
            height: 64, padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: AppColors.bg900,
              border: Border(bottom: BorderSide(color: AppColors.bg600)),
            ),
            child: Row(
              children: [
                Text('Alerts', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 12),
                if (motor.activeAlerts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${motor.activeAlerts.length} active',
                      style: const TextStyle(
                          color: AppColors.accentRed, fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textSecondary),
                  onPressed: motor.loadAlerts,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          Expanded(
            child: motor.activeAlerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentGreen.withValues(alpha: 0.1),
                          ),
                          child: const Icon(Icons.check_circle_outline_rounded,
                              size: 40, color: AppColors.accentGreen),
                        ),
                        const SizedBox(height: 16),
                        Text('No Active Alerts',
                          style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text('System is operating normally',
                          style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: motor.activeAlerts.length,
                    itemBuilder: (_, i) {
                      final alert = motor.activeAlerts[i];
                      return _AlertCard(
                        alert: alert,
                        canAck: auth.canOperate,
                        onAck: () => motor.acknowledgeAlert(alert.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final bool canAck;
  final VoidCallback onAck;

  const _AlertCard({
    required this.alert,
    required this.canAck,
    required this.onAck,
  });

  @override
  Widget build(BuildContext context) {
    final color = _sevColor(alert.severity);
    final dt = DateTime.fromMillisecondsSinceEpoch(
        (alert.timestamp * 1000).toInt());
    final timeStr = DateFormat('HH:mm:ss  dd MMM').format(dt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_sevIcon(alert.severity), size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(alert.severity.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: color, letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(alert.type,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontSize: 12)),
                      const Spacer(),
                      Text(timeStr,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(alert.message,
                    style: Theme.of(context).textTheme.bodyLarge),
                  if (alert.data.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alert.data.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('  |  '),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!alert.acknowledged && canAck)
              TextButton.icon(
                icon: const Icon(Icons.done_rounded, size: 16),
                label: const Text('Ack'),
                onPressed: onAck,
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  Color _sevColor(String sev) {
    switch (sev) {
      case 'critical': return AppColors.accentRed;
      case 'warning': return AppColors.accentAmber;
      default: return AppColors.primary;
    }
  }

  IconData _sevIcon(String sev) {
    switch (sev) {
      case 'critical': return Icons.error_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      default: return Icons.info_rounded;
    }
  }
}
