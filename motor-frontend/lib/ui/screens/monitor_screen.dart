// ============================================================
//  monitor_screen.dart  —  Full live data panel
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/theme/app_theme.dart';
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
            child: Consumer<MotorProvider>(
              builder: (_, motor, __) {
                final vfd = motor.latestData?.vfd;
                final pzem = motor.latestData?.pzem;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // VFD Block
                      SectionHeader(
                        title: 'VFD Readings (GD200A)',
                        subtitle: 'Real-time drive output parameters',
                        trailing: StatusChip(
                          label: motor.deviceConnected ? 'Live' : 'Offline',
                          color: motor.deviceConnected
                              ? AppColors.statusRunning
                              : AppColors.statusStopped,
                          pulsing: motor.deviceConnected,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16, runSpacing: 16,
                        children: [
                          _DataTile('Set Frequency', vfd?.setFreq, 'Hz',
                              Icons.tune_rounded, AppColors.primary),
                          _DataTile('Output Frequency', vfd?.outFreq, 'Hz',
                              Icons.waves_rounded, AppColors.accent),
                          _DataTile('Output Voltage', vfd?.outVolt, 'V',
                              Icons.flash_on_rounded, AppColors.accentOrange),
                          _DataTile('Output Current', vfd?.outCurr, 'A',
                              Icons.electrical_services_rounded, AppColors.accentAmber),
                          _DataTile('Motor RPM', vfd?.motorRpm?.toDouble(), 'RPM',
                              Icons.speed_rounded, AppColors.primary),
                          _DataTile('Active Power', vfd?.power, 'W',
                              Icons.power_rounded, AppColors.accentGreen),
                          _DataTile('Power Factor', vfd?.pf, '',
                              Icons.analytics_rounded, AppColors.accentRed),
                          _DataTile('Input Voltage', vfd?.inpVolt, 'V',
                              Icons.input_rounded, AppColors.primaryLight),
                          _DataTile('Proximity RPM', vfd?.proxRpm, 'RPM',
                              Icons.radar_rounded, AppColors.accent),
                          _DataTile('Phase R', vfd?.phaseR, 'V',
                              Icons.electric_bolt_rounded, const Color(0xFFFF6B6B)),
                          _DataTile('Phase Y', vfd?.phaseY, 'V',
                              Icons.electric_bolt_rounded, const Color(0xFFFFD93D)),
                          _DataTile('Phase B', vfd?.phaseB, 'V',
                              Icons.electric_bolt_rounded, const Color(0xFF6B9BFF)),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // PZEM Block
                      SectionHeader(
                        title: 'Power Meter (PZEM-004T)',
                        subtitle: 'AC supply measurements',
                        trailing: StatusChip(
                          label: motor.status?.pzemConnected == true
                              ? 'Live'
                              : 'Offline',
                          color: motor.status?.pzemConnected == true
                              ? AppColors.statusRunning
                              : AppColors.statusStopped,
                          pulsing: motor.status?.pzemConnected == true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16, runSpacing: 16,
                        children: [
                          _DataTile('Voltage', pzem?.voltage, 'V',
                              Icons.flash_on_rounded, AppColors.accentOrange),
                          _DataTile('Current', pzem?.current, 'A',
                              Icons.electrical_services_rounded, AppColors.accentAmber),
                          _DataTile('Active Power', pzem?.power, 'W',
                              Icons.power_rounded, AppColors.accentGreen),
                          _DataTile('Energy', pzem?.energy, 'Wh',
                              Icons.battery_charging_full_rounded, AppColors.primary),
                          _DataTile('Frequency', pzem?.freq, 'Hz',
                              Icons.waves_rounded, AppColors.accent),
                          _DataTile('Power Factor', pzem?.pf, '',
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
    return Container(
      height: 64, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.bg900,
        border: Border(bottom: BorderSide(color: AppColors.bg600)),
      ),
      child: Row(
        children: [
          Text('Live Monitor', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Consumer<MotorProvider>(
            builder: (_, motor, __) => IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: motor.refreshStatus,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
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
