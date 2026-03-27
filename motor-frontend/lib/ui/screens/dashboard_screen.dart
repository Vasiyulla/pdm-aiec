// ============================================================
//  dashboard_screen.dart  —  Main overview with KPIs + charts
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/widgets/motor_data_notifiers.dart';
import '../widgets/app_shell.dart';
import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final m = context.read<MotorProvider>();
      m.refreshStatus();
      m.loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.dashboard,
      child: _DashboardContent(),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final motor = context.read<MotorProvider>();
    final notifiers = context.read<MotorDataNotifiers>();
    final auth = context.watch<AuthProvider>();

    return ValueListenableBuilder(
      valueListenable: notifiers.vfd,
      builder: (context, vfd, _) {
        return ValueListenableBuilder(
          valueListenable: notifiers.pzem,
          builder: (context, pzem, _) {
            return ValueListenableBuilder(
              valueListenable: notifiers.charts,
              builder: (context, charts, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top bar ─────────────────────────────────────────────────
                    _TopBar(auth: auth, motor: motor, vfd: vfd),

                    // ── Content scroll ──────────────────────────────────────────
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final isWide = w > 1200;
                          final isMedium = w > 800;
                          final pad = isWide ? 24.0 : (isMedium ? 16.0 : 12.0);

                          return SingleChildScrollView(
                            padding: EdgeInsets.all(pad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // KPI Row — wraps on smaller screens
                                _buildKpiGrid(context, motor, vfd, pzem, isWide, isMedium),
                                const SizedBox(height: 24),

                                // Motor Control + Live Gauges
                                if (isWide)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 320,
                                        child: _MotorControlCard(motor: motor, auth: auth),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: RepaintBoundary(
                                          child: _TrendChart(
                                            title: 'RPM (Live)',
                                            data: charts.rpm,
                                            color: AppColors.primary,
                                            unit: 'RPM',
                                            maxY: 1600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: RepaintBoundary(
                                          child: _TrendChart(
                                            title: 'Torque (Live)',
                                            data: charts.torque,
                                            color: AppColors.accentAmber,
                                            unit: 'N·m',
                                            maxY: 30,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _MotorControlCard(motor: motor, auth: auth),
                                  const SizedBox(height: 16),
                                  if (isMedium)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RepaintBoundary(
                                            child: _TrendChart(
                                              title: 'RPM (Live)',
                                              data: charts.rpm,
                                              color: AppColors.primary,
                                              unit: 'RPM',
                                              maxY: 1600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: RepaintBoundary(
                                            child: _TrendChart(
                                              title: 'Torque (Live)',
                                              data: charts.torque,
                                              color: AppColors.accentAmber,
                                              unit: 'N·m',
                                              maxY: 30,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    RepaintBoundary(
                                      child: _TrendChart(
                                        title: 'RPM (Live)',
                                        data: charts.rpm,
                                        color: AppColors.primary,
                                        unit: 'RPM',
                                        maxY: 1600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    RepaintBoundary(
                                      child: _TrendChart(
                                        title: 'Torque (Live)',
                                        data: charts.torque,
                                        color: AppColors.accentAmber,
                                        unit: 'N·m',
                                        maxY: 30,
                                      ),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 24),

                                // Bottom row — Weight input + Charts + Alerts
                                if (isWide)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 300,
                                        child: _WeightInputCard(motor: motor),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: RepaintBoundary(
                                          child: _ScatterChart(
                                            title: 'Power vs Weight',
                                            data: motor.powerVsWeight,
                                            xKey: 'weight',
                                            yKey: 'power',
                                            xUnit: 'kg',
                                            yUnit: 'W',
                                            color: AppColors.accentGreen,
                                            maxY: 1200,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: RepaintBoundary(
                                          child: _ScatterChart(
                                            title: 'Torque vs Weight',
                                            data: motor.powerVsWeight,
                                            xKey: 'weight',
                                            yKey: 'torque',
                                            xUnit: 'kg',
                                            yUnit: 'N·m',
                                            color: AppColors.accentOrange,
                                            maxY: 30,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      SizedBox(
                                        width: 300,
                                        child: _AlertsCard(motor: motor),
                                      ),
                                    ],
                                  )
                                else ...[
                                  _WeightInputCard(motor: motor),
                                  const SizedBox(height: 16),
                                  if (isMedium)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RepaintBoundary(
                                            child: _ScatterChart(
                                              title: 'Power vs Weight',
                                              data: motor.powerVsWeight,
                                              xKey: 'weight',
                                              yKey: 'power',
                                              xUnit: 'kg',
                                              yUnit: 'W',
                                              color: AppColors.accentGreen,
                                              maxY: 1200,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: RepaintBoundary(
                                            child: _ScatterChart(
                                              title: 'Torque vs Weight',
                                              data: motor.powerVsWeight,
                                              xKey: 'weight',
                                              yKey: 'torque',
                                              xUnit: 'kg',
                                              yUnit: 'N·m',
                                              color: AppColors.accentOrange,
                                              maxY: 30,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    RepaintBoundary(
                                      child: _ScatterChart(
                                        title: 'Power vs Weight',
                                        data: motor.powerVsWeight,
                                        xKey: 'weight',
                                        yKey: 'power',
                                        xUnit: 'kg',
                                        yUnit: 'W',
                                        color: AppColors.accentGreen,
                                        maxY: 1200,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    RepaintBoundary(
                                      child: _ScatterChart(
                                        title: 'Torque vs Weight',
                                        data: motor.powerVsWeight,
                                        xKey: 'weight',
                                        yKey: 'torque',
                                        xUnit: 'kg',
                                        yUnit: 'N·m',
                                        color: AppColors.accentOrange,
                                        maxY: 30,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  _AlertsCard(motor: motor),
                                ],
                              ],
                            ),
                          );
                        },
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


  Widget _buildKpiGrid(BuildContext context, MotorProvider motor,
      vfd, pzem, bool isWide, bool isMedium) {
    String fmt(double? v, int d) =>
        v == null ? '--' : v.toStringAsFixed(d);

    final tiles = <Widget>[
      MetricTile(
        label: 'Motor Speed',
        value: fmt(vfd?.motorRpm?.toDouble(), 0),
        unit: 'RPM',
        icon: Icons.speed_rounded,
        color: AppColors.primary,
        progress: (vfd?.motorRpm ?? 0) / 1500,
      ),
      MetricTile(
        label: 'Frequency',
        value: fmt(vfd?.outFreq, 1),
        unit: 'Hz',
        icon: Icons.waves_rounded,
        color: AppColors.accent,
        progress: (vfd?.outFreq ?? 0) / 50,
      ),
      MetricTile(
        label: 'Output Current',
        value: fmt(vfd?.outCurr ?? pzem?.current, 2),
        unit: 'A',
        icon: Icons.electrical_services_rounded,
        color: AppColors.accentAmber,
        progress: (vfd?.outCurr ?? pzem?.current ?? 0) / 10,
      ),
      MetricTile(
        label: 'Line Voltage',
        value: fmt(pzem?.voltage ?? vfd?.inpVolt, 1),
        unit: 'V',
        icon: Icons.flash_on_rounded,
        color: AppColors.accentOrange,
      ),
      MetricTile(
        label: 'Output Volt',
        value: fmt(vfd?.outVolt, 0),
        unit: 'V',
        icon: Icons.electric_bolt_rounded,
        color: AppColors.accent,
      ),
      MetricTile(
        label: 'Active Power',
        value: fmt(vfd?.power ?? pzem?.power, 0),
        unit: 'W',
        icon: Icons.power_rounded,
        color: AppColors.accentGreen,
      ),
      MetricTile(
        label: 'Power Factor',
        value: fmt(vfd?.pf ?? pzem?.pf, 2),
        unit: 'PF',
        icon: Icons.analytics_rounded,
        color: AppColors.accentRed,
        progress: vfd?.pf ?? pzem?.pf,
      ),
    ];

    // Responsive: use Wrap so tiles flow to next row on smaller screens
    final cols = isWide ? 7 : (isMedium ? 4 : 2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final tileW = (constraints.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles.map((t) => SizedBox(width: tileW, child: t)).toList(),
        );
      },
    );
  }
}

// ── Top bar
class _TopBar extends StatelessWidget {
  final AuthProvider auth;
  final MotorProvider motor;
  final VfdSnapshot vfd;

  const _TopBar({required this.auth, required this.motor, required this.vfd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bg900 : AppColors.lightSurface,
        border: Border(
            bottom: BorderSide(
                color: isDark ? AppColors.bg600 : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard',
                style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Last update: ${_ts(DateTime.now().millisecondsSinceEpoch / 1000.0)}',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          // Connection status
          StatusChip(
            label: motor.deviceConnected ? 'VFD Online' : 'VFD Offline',
            color: motor.deviceConnected
                ? AppColors.statusRunning
                : AppColors.statusStopped,
            pulsing: motor.deviceConnected,
          ),
          const SizedBox(width: 10),
          if (vfd.motorRpm > 0)
            StatusChip(
              label: 'Motor Running',
              color: AppColors.statusRunning,
              pulsing: true,
            )
          else
            StatusChip(label: 'Motor Stopped', color: AppColors.statusStopped),
          const SizedBox(width: 16),

          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Refresh',
            onPressed: () {
              motor.refreshStatus();
              motor.loadAlerts();
            },
          ),
        ],
      ),
    );
  }

  String _ts(double ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    return DateFormat('HH:mm:ss').format(dt);
  }
}

// ── Motor control card
class _MotorControlCard extends StatefulWidget {
  final MotorProvider motor;
  final AuthProvider auth;
  const _MotorControlCard({required this.motor, required this.auth});

  @override
  State<_MotorControlCard> createState() => _MotorControlCardState();
}

class _MotorControlCardState extends State<_MotorControlCard> {
  double _freq = 25.0;
  String _direction = 'forward';

  Future<void> _start() async {
    final res = await widget.motor.startMotor(
      direction: _direction, frequency: _freq,
    );
    _showResult(res);
  }

  Future<void> _stop() async {
    final res = await widget.motor.stopMotor();
    _showResult(res);
  }

  Future<void> _eStop() async {
    final res = await widget.motor.eStop();
    _showResult(res);
  }

  Future<void> _reset() async {
    final res = await widget.motor.resetFault();
    _showResult(res);
  }

  void _showResult(Map<String, dynamic> res) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            res['success'] == true
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            color: res['success'] == true
                ? AppColors.accentGreen
                : AppColors.accentRed,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(res['message'] ?? '')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.motor.isRunning;
    final canOp = widget.auth.canOperate;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Motor Control',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),

          // Motor state indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _stateColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stateColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_stateIcon, size: 24, color: _stateColor),
                const SizedBox(width: 10),
                Text(widget.motor.motorState,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: _stateColor, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: (Theme.of(context).brightness == Brightness.dark 
                ? AppColors.bg500 
                : AppColors.lightBorder).withValues(alpha: 0.5),
            height: 24,
          ),
          const SizedBox(height: 12),

          // Direction selector (Segmented Toggle)
          if (!running) ...[
            Text('Direction', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 290, // ~140 + 8 + 140 + a bit for border padding
                height: 38,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.bg700 : AppColors.lightBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? AppColors.bg500 : AppColors.lightBorder)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _segmentedBtn('forward', Icons.arrow_forward_rounded, 'Forward'),
                    ),
                    Expanded(
                      child: _segmentedBtn('reverse', Icons.arrow_back_rounded, 'Reverse'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Frequency slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Frequency', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${_freq.toStringAsFixed(1)} Hz',
                   style: Theme.of(context).textTheme.labelLarge
                       ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _freq,
                min: 0.5, max: 50.0,
                divisions: 99,
                activeColor: AppColors.primary,
                inactiveColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.bg600
                    : AppColors.lightBorder,
                onChanged: canOp ? (v) => setState(() => _freq = v) : null,
              ),
            ),
          ] else ...[
            // Frequency adjustment while running
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Adjust Speed', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${_freq.toStringAsFixed(1)} Hz',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _freq,
                min: 0.5, max: 50.0,
                divisions: 99,
                activeColor: AppColors.primary,
                inactiveColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.bg600
                    : AppColors.lightBorder,
                onChanged: canOp ? (v) => setState(() => _freq = v) : null,
                onChangeEnd: canOp
                    ? (v) => widget.motor.setFrequency(v)
                    : null,
              ),
            ),
          ],

          const SizedBox(height: 4),

          // Command buttons
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44, // 44px Start
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Start', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    onPressed: canOp && !running ? _start : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusRunning,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.statusRunning.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: const Text('Stop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    onPressed: canOp ? _stop : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusFault,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40, // 40px E-Stop
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.warning_amber_rounded, size: 15),
                    label: const Text('E-Stop', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: canOp ? _eStop : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentRed,
                      side: const BorderSide(color: AppColors.accentRed),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40, // 40px Reset
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded, size: 15),
                    label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: canOp ? _reset : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.accentAmber,
                      side: const BorderSide(color: AppColors.accentAmber),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!canOp) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppColors.accentAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Viewer role — read only',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontSize: 11, color: AppColors.accentAmber),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segmentedBtn(String dir, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = _direction == dir;
    final inactiveColor = isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
    
    return GestureDetector(
      onTap: () => setState(() => _direction = dir),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14,
                color: active ? Colors.white : inactiveColor),
            const SizedBox(width: 6),
            Text(label,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.white : inactiveColor,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _stateColor {
    switch (widget.motor.motorState) {
      case 'FWD': case 'REV': return AppColors.statusRunning;
      case 'FAULT': return AppColors.statusFault;
      default: return AppColors.statusStopped;
    }
  }

  IconData get _stateIcon {
    switch (widget.motor.motorState) {
      case 'FWD': return Icons.rotate_right_rounded;
      case 'REV': return Icons.rotate_left_rounded;
      case 'FAULT': return Icons.error_rounded;
      default: return Icons.stop_circle_outlined;
    }
  }
}

// ── Trend chart
class _TrendChart extends StatelessWidget {
  final String title;
  final List<double> data;
  final Color color;
  final String unit;
  final double maxY;

  const _TrendChart({
    required this.title,
    required this.data,
    required this.color,
    required this.unit,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (data.isNotEmpty)
                Text(
                  '${data.last.toStringAsFixed(1)} $unit',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: color),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: data.isEmpty
                ? Center(
                    child: Text('No data',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.textMuted)),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0, maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.bg500
                                  : AppColors.lightBorder)
                              .withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: false,
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: color,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.08),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Weight input card (S1 & S2 spring balance)
class _WeightInputCard extends StatefulWidget {
  final MotorProvider motor;
  const _WeightInputCard({required this.motor});

  @override
  State<_WeightInputCard> createState() => _WeightInputCardState();
}

class _WeightInputCardState extends State<_WeightInputCard> {
  final _s1Controller = TextEditingController();
  final _s2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _s1Controller.text = widget.motor.s1 > 0 ? widget.motor.s1.toStringAsFixed(1) : '';
    _s2Controller.text = widget.motor.s2 > 0 ? widget.motor.s2.toStringAsFixed(1) : '';
  }

  @override
  void dispose() {
    _s1Controller.dispose();
    _s2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final running = widget.motor.isRunning;
    final dataPoints = widget.motor.powerVsWeight.length;
    final netWeight = widget.motor.weight;
    final textColor = isDark ? AppColors.textPrimary : const Color(0xFF1A1A2E);
    final subtleText = isDark ? AppColors.textSecondary : const Color(0xFF64748B);
    final fieldBg = isDark ? AppColors.bg700 : const Color(0xFFF1F5F9);
    final fieldBorder = isDark ? AppColors.bg500 : const Color(0xFFCBD5E1);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    size: 14, color: AppColors.accentOrange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Load Analysis',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      )),
                    Text('Spring balance readings',
                      style: TextStyle(fontSize: 10, color: subtleText)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // S1 and S2 input fields side by side
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  context: context,
                  label: 'S1 (Load)',
                  controller: _s1Controller,
                  color: AppColors.primary,
                  fieldBg: fieldBg,
                  fieldBorder: fieldBorder,
                  subtleText: subtleText,
                  onChanged: (v) {
                    final val = double.tryParse(v);
                    if (val != null) widget.motor.setS1(val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  context: context,
                  label: 'S2 (Tare)',
                  controller: _s2Controller,
                  color: AppColors.accent,
                  fieldBg: fieldBg,
                  fieldBorder: fieldBorder,
                  subtleText: subtleText,
                  onChanged: (v) {
                    final val = double.tryParse(v);
                    if (val != null) widget.motor.setS2(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Net weight display badge
          Container(
            width: double.infinity,
            height: 36, // 36px height
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accentOrange.withValues(alpha: 0.12),
                  AppColors.accentAmber.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.accentOrange.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Net Weight (|S1 − S2|)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: subtleText)),
                Text('${netWeight.toStringAsFixed(2)} kg',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentOrange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Current live readings display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: fieldBorder.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                _miniStat(context, 'Power',
                  '${(widget.motor.latestData?.vfd?.power ?? 0).toStringAsFixed(0)} W',
                  AppColors.accentGreen, subtleText),
                const SizedBox(height: 4),
                _miniStat(context, 'Torque',
                  '${_currentTorque.toStringAsFixed(2)} N·m',
                  AppColors.accentOrange, subtleText),
                const SizedBox(height: 4),
                _miniStat(context, 'Data Points',
                  '$dataPoints',
                  AppColors.primary, subtleText),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Record + Clear in a row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_chart_rounded, size: 14),
                    label: const Text('Record Data Point',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: running
                        ? () => widget.motor.recordWeightDataPoint()
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: OutlinedButton(
                  onPressed: dataPoints > 0
                      ? () => widget.motor.clearWeightData()
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),

          if (!running) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentAmber.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.accentAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Start motor to record data',
                      style: TextStyle(
                        fontSize: 10, color: AppColors.accentAmber, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required String label,
    required TextEditingController controller,
    required Color color,
    required Color fieldBg,
    required Color fieldBorder,
    required Color subtleText,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: subtleText)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38, // 40px desired, but we can use 38 for tighter feel
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textPrimary
                  : const Color(0xFF1A1A2E),
            ),
            decoration: InputDecoration(
              suffixText: 'kg',
              suffixStyle: TextStyle(
                color: subtleText.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              hintText: '0.0',
              hintStyle: TextStyle(color: subtleText.withValues(alpha: 0.4)),
              filled: true,
              fillColor: fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 0),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  double get _currentTorque {
    final rpm = widget.motor.latestData?.vfd?.motorRpm?.toDouble() ?? 0;
    final power = widget.motor.latestData?.vfd?.power ?? 0;
    if (rpm > 1) {
      final omega = 2 * 3.14159265 * rpm / 60.0;
      return power / omega;
    }
    return 0;
  }

  Widget _miniStat(BuildContext ctx, String label, String value,
      Color color, Color subtleText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subtleText)),
        Text(value, style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Scatter chart (Power/Torque vs Weight)
class _ScatterChart extends StatelessWidget {
  final String title;
  final List<Map<String, double>> data;
  final String xKey;
  final String yKey;
  final String xUnit;
  final String yUnit;
  final Color color;
  final double maxY;

  const _ScatterChart({
    required this.title,
    required this.data,
    required this.xKey,
    required this.yKey,
    required this.xUnit,
    required this.yUnit,
    required this.color,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by x for line rendering
    final sorted = List<Map<String, double>>.from(data)
      ..sort((a, b) => (a[xKey] ?? 0).compareTo(b[xKey] ?? 0));
    final spots = sorted
        .map((e) => FlSpot(e[xKey] ?? 0, e[yKey] ?? 0))
        .toList();

    final dynMaxY = spots.isEmpty
        ? maxY
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.3)
            .clamp(1.0, maxY * 2);
    final dynMaxX = spots.isEmpty
        ? 100.0
        : (spots.map((s) => s.x).reduce((a, b) => a > b ? a : b) * 1.3)
            .clamp(1.0, 10000.0);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (spots.isNotEmpty)
                Text(
                  '${spots.last.y.toStringAsFixed(1)} $yUnit',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: color),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.scatter_plot_rounded,
                            size: 32, color: AppColors.textMuted),
                        const SizedBox(height: 6),
                        Text('Apply weight & record data',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0, maxY: dynMaxY,
                      minX: 0, maxX: dynMaxX,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.bg500
                                  : AppColors.lightBorder)
                              .withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (_) => FlLine(
                          color: (Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.bg500
                                  : AppColors.lightBorder)
                              .withValues(alpha: 0.3),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (val, meta) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${val.toStringAsFixed(0)}$xUnit',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontSize: 9, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: spots.length > 2,
                          color: color,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, pct, bar, idx) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: color,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots.map((s) =>
                            LineTooltipItem(
                              '${s.x.toStringAsFixed(1)}$xUnit → ${s.y.toStringAsFixed(1)}$yUnit',
                              TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Alerts summary card
class _AlertsCard extends StatelessWidget {
  final MotorProvider motor;
  const _AlertsCard({required this.motor});

  @override
  Widget build(BuildContext context) {
    final alerts = motor.activeAlerts.take(5).toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_rounded,
                  size: 18, color: AppColors.accentRed),
              const SizedBox(width: 8),
              Text('Active Alerts',
                style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('${motor.activeAlerts.length}',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.accentRed)),
            ],
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 36, color: AppColors.accentGreen),
                    const SizedBox(height: 8),
                    Text('All clear', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            ...alerts.map((a) => _AlertRow(alert: a))
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final dynamic alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final sev = alert.severity as String;
    final color = sev == 'critical'
        ? AppColors.accentRed
        : sev == 'warning'
            ? AppColors.accentAmber
            : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.message as String,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
