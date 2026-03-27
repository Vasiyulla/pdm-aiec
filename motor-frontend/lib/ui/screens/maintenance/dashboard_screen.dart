import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:motor_frontend/core/providers/maintenance_provider.dart';
import 'package:motor_frontend/core/theme/app_theme.dart';
import 'package:motor_frontend/ui/widgets/app_shell.dart';
import 'package:motor_frontend/ui/widgets/glass_card.dart';
import 'package:motor_frontend/ui/widgets/premium_button.dart';
import 'package:motor_frontend/ui/router/app_router.dart';

class MaintenanceDashboard extends StatefulWidget {
  const MaintenanceDashboard({super.key});

  @override
  State<MaintenanceDashboard> createState() => _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends State<MaintenanceDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaintenanceProvider>().fetchMachines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.maintenance,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<MaintenanceProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.machines.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 1000;
                final isMedium = constraints.maxWidth > 700;
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 24),
                      _buildSummaryCards(isWide, isMedium, provider),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildMachineGrid(provider)),
                            const SizedBox(width: 24),
                            Expanded(flex: 2, child: _buildRiskDistribution(provider)),
                          ],
                        )
                      else ...[
                        _buildRiskDistribution(provider),
                        const SizedBox(height: 24),
                        _buildMachineGrid(provider),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Predictive Maintenance',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
            Text('AI-driven machine health and failure risk analysis',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    )),
          ],
        ),
        PremiumButton(
          label: 'Run Analysis',
          icon: Icons.analytics_rounded,
          onPressed: () => Navigator.pushNamed(context, AppRouter.maintenanceAnalyze),
          height: 40,
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isWide, bool isMedium, MaintenanceProvider p) {
    final cols = isWide ? 4 : (isMedium ? 2 : 1);
    final count = p.machines.length;
    final atRisk = p.machines.where((m) => m['status'] != 'Active').length;

    final tiles = <Widget>[
      MetricTile(label: 'Total Machines', value: '$count', unit: 'UNITS', icon: Icons.precision_manufacturing_rounded, color: AppColors.primary),
      MetricTile(label: 'At Risk', value: '$atRisk', unit: 'CRITICAL', icon: Icons.warning_amber_rounded, color: AppColors.accentRed),
      MetricTile(label: 'Healthy Assets', value: '${count - atRisk}', unit: 'STABLE', icon: Icons.check_circle_outline_rounded, color: AppColors.accentGreen),
      MetricTile(label: 'System Health', value: '${count == 0 ? 100 : (100 - (atRisk / count * 100).toInt())}%', unit: 'SCORE', icon: Icons.health_and_safety_rounded, color: AppColors.accentGreen),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 16.0;
        final tileW = (constraints.maxWidth - (cols - 1) * gap) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: tiles.map((t) => SizedBox(width: tileW, child: t)).toList(),
        );
      },
    );
  }

  Widget _buildMachineGrid(MaintenanceProvider p) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monitored Assets', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: p.machines.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (context, index) {
              final m = p.machines[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.settings_input_component_rounded, color: AppColors.primary),
                ),
                title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${m['type']} • ${m['location']}'),
                trailing: StatusChip(
                  label: m['status'],
                  color: m['status'] == 'Active' ? AppColors.accentGreen : AppColors.accentOrange,
                ),
                onTap: () => Navigator.pushNamed(context, '/machine-detail', arguments: m['id']),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRiskDistribution(MaintenanceProvider p) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk Distribution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: _buildPieSections(p),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendItem('Normal', AppColors.accentGreen),
          _buildLegendItem('Monitoring', AppColors.accentAmber),
          _buildLegendItem('At Risk', AppColors.accentOrange),
          _buildLegendItem('Critical', AppColors.accentRed),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(MaintenanceProvider p) {
    if (p.machines.isEmpty) {
      return [PieChartSectionData(value: 1, color: Colors.white10, title: '', radius: 25)];
    }
    
    final active = p.machines.where((m) => m['status'] == 'Active').length;
    final warning = p.machines.where((m) => m['status'] == 'Warning').length;
    final critical = p.machines.where((m) => m['status'] == 'Critical').length;
    final total = p.machines.length;

    return [
      PieChartSectionData(
        value: active.toDouble(),
        color: AppColors.accentGreen,
        title: '${(active / total * 100).toInt()}%',
        radius: 25,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: warning.toDouble(),
        color: AppColors.accentOrange,
        title: '${(warning / total * 100).toInt()}%',
        radius: 25,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: critical.toDouble(),
        color: AppColors.accentRed,
        title: '${(critical / total * 100).toInt()}%',
        radius: 25,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
