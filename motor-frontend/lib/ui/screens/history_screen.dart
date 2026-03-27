// ============================================================
//  history_screen.dart  —  Historical data + trend chart
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _metric = 'rpm';
  static const _metrics = {
    'rpm': 'Motor RPM',
    'freq': 'Frequency (Hz)',
    'curr': 'Current (A)',
    'volt': 'Voltage (V)',
    'power': 'Power (W)',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotorProvider>().loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorProvider>();
    final rows = motor.history;

    return AppShell(
      currentRoute: AppRouter.history,
      child: Column(
        children: [
          // Header
          Container(
            height: 64, padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? AppColors.bg900 
                  : AppColors.lightSurface,
              border: Border(bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.bg600 
                      : AppColors.lightBorder, 
                  width: 0.5)),
            ),
            child: Row(
              children: [
                Text('History', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 20),
                // Metric selector
                DropdownButton<String>(
                  value: _metric,
                  dropdownColor: Theme.of(context).brightness == Brightness.dark 
                      ? AppColors.bg700 
                      : AppColors.lightSurface,
                  items: _metrics.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))
                  ).toList(),
                  onChanged: (v) => setState(() => _metric = v ?? 'rpm'),
                  style: Theme.of(context).textTheme.bodyMedium,
                  underline: const SizedBox(),
                ),
                const Spacer(),
                Text('${rows.length} records',
                  style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: AppColors.textSecondary),
                  onPressed: motor.loadHistory,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chart
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_metrics[_metric] ?? '',
                          style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 260,
                          child: rows.isEmpty
                              ? Center(
                                  child: Text('No historical data',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(color: AppColors.textMuted)),
                                )
                              : LineChart(_buildChart(rows)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Table
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data Table',
                          style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        // Header
                        _tableHeader(context),
                        Divider(
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? AppColors.bg500 
                              : AppColors.lightBorder, 
                          height: 16
                        ),
                        // Rows
                        ...rows.take(100).map((r) => _tableRow(context, r)),
                      ],
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

  LineChartData _buildChart(List<Map<String, dynamic>> rows) {
    final samples = rows.length > 200
        ? rows.sublist(rows.length - 200)
        : rows;

    final spots = samples.asMap().entries.map((e) {
      final v = _extractMetric(e.value);
      return FlSpot(e.key.toDouble(), v);
    }).toList();

    final maxY = spots.isEmpty
        ? 100.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1;

    return LineChartData(
      minY: 0, maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: Color(0x1AFFFFFF), strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, reservedSize: 28,
            getTitlesWidget: (v, _) {
              if (v.toInt() % 20 != 0) return const SizedBox();
              return Text(v.toInt().toString(),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, reservedSize: 42,
            getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }

  double _extractMetric(Map<String, dynamic> row) {
    switch (_metric) {
      case 'rpm': return (row['motor_rpm'] as num?)?.toDouble() ?? 0;
      case 'freq': return (row['out_freq'] as num?)?.toDouble() ?? 0;
      case 'curr': return (row['out_curr'] as num?)?.toDouble() ?? 0;
      case 'volt': return (row['out_volt'] as num?)?.toDouble() ?? 0;
      case 'power': return (row['power'] as num?)?.toDouble() ?? 0;
      default: return 0;
    }
  }

  Widget _tableHeader(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 2, child: _TH('Timestamp')),
        Expanded(child: _TH('RPM')),
        Expanded(child: _TH('Freq (Hz)')),
        Expanded(child: _TH('Curr (A)')),
        Expanded(child: _TH('Volt (V)')),
        Expanded(child: _TH('State')),
      ],
    );
  }

  Widget _tableRow(BuildContext context, Map<String, dynamic> row) {
    final ts = (row['timestamp'] as num?)?.toDouble() ?? 0;
    final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
    final timeStr = DateFormat('HH:mm:ss dd/MM').format(dt);
    final state = row['motor_state'] as String? ?? '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.bg600 
                : AppColors.lightBorder, 
            width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2,
            child: Text(timeStr,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary,
                  fontFamily: 'monospace')),
          ),
          _td(row['motor_rpm']),
          _td(row['out_freq']),
          _td(row['out_curr']),
          _td(row['out_volt']),
          Expanded(
            child: StatusChip(
              label: state,
              color: state == 'FWD' || state == 'REV'
                  ? AppColors.statusRunning
                  : AppColors.statusStopped,
            ),
          ),
        ],
      ),
    );
  }

  Widget _td(dynamic v) => Expanded(
    child: Text(
      v == null ? '--' : (v as num).toStringAsFixed(1),
      style: TextStyle(
          fontSize: 12, 
          color: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.textPrimary 
              : AppColors.lightTextPrimary),
    ),
  );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: Theme.of(context).brightness == Brightness.dark 
          ? AppColors.textSecondary 
          : AppColors.lightTextSecondary, 
      letterSpacing: 0.5,
    ),
  );
}
