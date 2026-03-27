// ============================================================
//  monitor_screen.dart  —  Full live data panel
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/widgets/motor_data_notifiers.dart';
import '../widgets/app_shell.dart';
import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.monitor,
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: Builder(
              builder: (context) {
                final notifiers = context.read<MotorDataNotifiers>();
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // VFD Block
                      SectionHeader(
                        title: 'VFD Readings (GD200A)',
                        subtitle: 'Real-time drive output parameters',
                        trailing: Consumer<MotorProvider>(
                          builder: (_, motor, __) => StatusChip(
                            label: motor.deviceConnected ? 'Live' : 'Offline',
                            color: motor.deviceConnected
                                ? AppColors.statusRunning
                                : AppColors.statusStopped,
                            pulsing: motor.deviceConnected,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16, runSpacing: 16,
                        children: [
                          _ListenableDataTile<VfdSnapshot>('Set Frequency', notifiers.vfd, (v) => v.setFreq, 'Hz',
                              Icons.tune_rounded, AppColors.primary),
                          _ListenableDataTile<VfdSnapshot>('Output Frequency', notifiers.vfd, (v) => v.outFreq, 'Hz',
                              Icons.waves_rounded, AppColors.accent),
                          _ListenableDataTile<VfdSnapshot>('Output Voltage', notifiers.vfd, (v) => v.outVolt, 'V',
                              Icons.flash_on_rounded, AppColors.accentOrange),
                          _ListenableDataTile<VfdSnapshot>('Output Current', notifiers.vfd, (v) => v.outCurr, 'A',
                              Icons.electrical_services_rounded, AppColors.accentAmber),
                          _ListenableDataTile<VfdSnapshot>('Motor RPM', notifiers.vfd, (v) => v.motorRpm.toDouble(), 'RPM',
                              Icons.speed_rounded, AppColors.primary),
                          _ListenableDataTile<VfdSnapshot>('Active Power', notifiers.vfd, (v) => v.power, 'W',
                              Icons.power_rounded, AppColors.accentGreen),
                          _ListenableDataTile<VfdSnapshot>('Power Factor', notifiers.vfd, (v) => v.pf, '',
                              Icons.analytics_rounded, AppColors.accentRed),
                          _ListenableDataTile<VfdSnapshot>('Input Voltage', notifiers.vfd, (v) => v.inpVolt, 'V',
                              Icons.input_rounded, AppColors.primaryLight),
                          _ListenableDataTile<VfdSnapshot>('Proximity RPM', notifiers.vfd, (v) => v.proxRpm, 'RPM',
                              Icons.radar_rounded, AppColors.accent),
                          // Static ones
                          const _DataTile('Phase R', 0, 'V',
                              Icons.electric_bolt_rounded, Color(0xFFFF6B6B)),
                          const _DataTile('Phase Y', 0, 'V',
                              Icons.electric_bolt_rounded, Color(0xFFFFD93D)),
                          const _DataTile('Phase B', 0, 'V',
                              Icons.electric_bolt_rounded, Color(0xFF6B9BFF)),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // PZEM Block
                      SectionHeader(
                        title: 'Power Meter (PZEM-004T)',
                        subtitle: 'AC supply measurements',
                        trailing: Consumer<MotorProvider>(
                          builder: (_, motor, __) => StatusChip(
                            label: motor.deviceConnected ? 'Live' : 'Offline',
                            color: motor.deviceConnected
                                ? AppColors.statusRunning
                                : AppColors.statusStopped,
                            pulsing: motor.deviceConnected,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16, runSpacing: 16,
                        children: [
                          _ListenableDataTile<PzemSnapshot>('Voltage', notifiers.pzem, (v) => v.voltage, 'V',
                              Icons.flash_on_rounded, AppColors.accentOrange),
                          _ListenableDataTile<PzemSnapshot>('Current', notifiers.pzem, (v) => v.current, 'A',
                              Icons.electrical_services_rounded, AppColors.accentAmber),
                          _ListenableDataTile<PzemSnapshot>('Active Power', notifiers.pzem, (v) => v.power, 'W',
                              Icons.power_rounded, AppColors.accentGreen),
                          const _DataTile('Energy', 0, 'Wh',
                              Icons.battery_charging_full_rounded, AppColors.primary),
                          _ListenableDataTile<PzemSnapshot>('Frequency', notifiers.pzem, (v) => v.freq, 'Hz',
                              Icons.waves_rounded, AppColors.accent),
                          _ListenableDataTile<PzemSnapshot>('Power Factor', notifiers.pzem, (v) => v.pf, '',
                              Icons.analytics_rounded, AppColors.accentRed),
                        ],
                      ),
                      const SizedBox(height: 24),
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

  Widget _header(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bg900 : AppColors.lightSurface,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.bg600 : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Text('Live Monitor', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Consumer<MotorProvider>(
            builder: (_, motor, __) {
              final isRunning = motor.isRunning;
              return Row(
                children: [
                  if (isRunning)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.stop_rounded, size: 18),
                        label: const Text('STOP MOTOR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        onPressed: motor.stopMotor,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusFault,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          elevation: 0,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                    onPressed: motor.refreshStatus,
                    tooltip: 'Refresh',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ListenableDataTile<T> extends StatelessWidget {
  final String label;
  final ValueListenable<T> valueListenable;
  final double Function(T) mapper;
  final String unit;
  final IconData icon;
  final Color color;

  const _ListenableDataTile(this.label, this.valueListenable, this.mapper, this.unit, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<T>(
      valueListenable: valueListenable,
      builder: (context, val, _) {
        return _DataTile(label, mapper(val), unit, icon, color);
      },
    );
  }
}

class _DataTile extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final IconData icon;
  final Color color;

  const _DataTile(this.label, this.value, this.unit, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const Spacer(),
                Text(unit,
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value == null
                  ? '—'
                  : unit == ''
                      ? value!.toStringAsFixed(3)
                      : value!.toStringAsFixed(unit == 'RPM' || unit == 'Wh' ? 0 : 2),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 22, fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
