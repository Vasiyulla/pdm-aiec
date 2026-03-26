import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:motor_frontend/core/theme/app_theme.dart';
import 'package:motor_frontend/ui/widgets/app_shell.dart';
import 'package:motor_frontend/ui/widgets/glass_card.dart';
import 'package:motor_frontend/ui/router/app_router.dart';

class MachineDetailScreen extends StatelessWidget {
  final String machineId;
  const MachineDetailScreen({super.key, required this.machineId});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.maintenanceDetail,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildTopRow(context),
              const SizedBox(height: 24),
              _buildTrendChart(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Machine #$machineId', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
             Text('Industrial VFD Motor A • Sector 7G Floor 1', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        const Spacer(),
        const StatusChip(label: 'Active', color: AppColors.accentGreen, pulsing: true),
      ],
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: isWide ? 2 : 5, child: _buildGaugesGrid(context)),
            const SizedBox(width: 24),
            Expanded(flex: isWide ? 1 : 5, child: _buildHealthCard(context)),
          ],
        );
      },
    );
  }

  Widget _buildGaugesGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildGaugeItem('Temperature', '42.5', '°C', AppColors.accentRed, 0.4),
        _buildGaugeItem('Vibration', '1.2', 'mm/s', AppColors.primary, 0.2),
        _buildGaugeItem('Pressure', '8.4', 'Bar', AppColors.accent, 0.3),
        _buildGaugeItem('Motor Speed', '1450', 'RPM', AppColors.accentGreen, 0.7),
      ],
    );
  }

  Widget _buildGaugeItem(String label, String value, String unit, Color color, double progress) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(unit, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.bold)),
         ]),
         const SizedBox(height: 12),
         Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
         const SizedBox(height: 8),
         LinearProgressIndicator(value: progress, backgroundColor: Colors.white10, color: color, minHeight: 4),
      ]),
    );
  }

  Widget _buildHealthCard(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.accentGreen.withValues(alpha: 0.3),
      child: const Column(children: [
         Text('OVERALL HEALTH', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
         SizedBox(height: 24),
         Stack(alignment: Alignment.center, children: [
            SizedBox(
              height: 120, width: 120,
              child: CircularProgressIndicator(value: 0.94, strokeWidth: 10, backgroundColor: Colors.white10, color: AppColors.accentGreen),
            ),
            Text('94%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
         ]),
         SizedBox(height: 16),
         Text('Low Failure Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
         SizedBox(height: 4),
         Text('Next maintenance: 12 May 2026', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ]),
    );
  }

  Widget _buildTrendChart(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text('Health Trend (Last 30 Days)', style: Theme.of(context).textTheme.titleLarge),
         const SizedBox(height: 24),
         SizedBox(
           height: 240,
           child: LineChart(
             LineChartData(
               gridData: const FlGridData(show: true, drawVerticalLine: false),
               titlesData: const FlTitlesData(
                 leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                 bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22)),
                 topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
               ),
               borderData: FlBorderData(show: false),
               lineBarsData: [
                 LineChartBarData(
                   spots: const [FlSpot(0, 95), FlSpot(5, 94), FlSpot(10, 92), FlSpot(15, 96), FlSpot(20, 94), FlSpot(25, 93), FlSpot(30, 94)],
                   isCurved: true,
                   color: AppColors.accentGreen,
                   barWidth: 3,
                   dotData: const FlDotData(show: true),
                   belowBarData: BarAreaData(show: true, color: AppColors.accentGreen.withValues(alpha: 0.1)),
                 ),
               ],
             ),
           ),
         ),
      ]),
    );
  }
}
