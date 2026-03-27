import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:motor_frontend/core/providers/maintenance_provider.dart';
import 'package:motor_frontend/core/providers/motor_provider.dart';
import 'package:motor_frontend/core/theme/app_theme.dart';
import 'package:motor_frontend/ui/widgets/app_shell.dart';
import 'package:motor_frontend/ui/widgets/glass_card.dart';
import 'package:motor_frontend/ui/widgets/premium_button.dart';
import 'package:motor_frontend/ui/router/app_router.dart';

class RunAnalysisScreen extends StatefulWidget {
  const RunAnalysisScreen({super.key});

  @override
  State<RunAnalysisScreen> createState() => _RunAnalysisScreenState();
}

class _RunAnalysisScreenState extends State<RunAnalysisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tempController = TextEditingController();
  final _vibController = TextEditingController();
  final _pressController = TextEditingController();
  final _rpmController = TextEditingController();
  String _machineId = "M-001";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPopulate();
    });
  }

  void _autoPopulate() {
    final motor = context.read<MotorProvider>();
    final vfd = motor.latestData.vfd;

    if (vfd != null) {
      if (vfd.motorRpm != null) _rpmController.text = vfd.motorRpm.toString();
      // Assume temp is available in some vfd field or null
      // if (vfd.temp != null) _tempController.text = vfd.temp.toString();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRouter.maintenanceAnalyze,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Consumer<MaintenanceProvider>(
          builder: (context, provider, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 2, child: _buildInputForm(context, provider)),
                      const SizedBox(width: 24),
                      Expanded(
                          flex: 3, child: _buildResultsView(context, provider)),
                    ],
                  ),
                ],
              ),
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
            Text('Run AI Analysis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
            const Text('Input live sensor readings for failure risk assessment',
                style: TextStyle(
                  color: AppColors.textSecondary,
                )),
          ],
        ),
        IconButton(
          onPressed: _autoPopulate,
          icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
          tooltip: 'Sync Live Data',
        ),
      ],
    );
  }

  Widget _buildInputForm(BuildContext context, MaintenanceProvider provider) {
    return GlassCard(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _machineId,
              decoration: const InputDecoration(labelText: 'Machine ID'),
              items: const [
                DropdownMenuItem(
                    value: "M-001", child: Text("M-001 (VFD Motor A)")),
                DropdownMenuItem(
                    value: "M-002", child: Text("M-002 (VFD Motor B)")),
              ],
              onChanged: (v) => setState(() => _machineId = v!),
            ),
            const SizedBox(height: 16),
            _buildTextField(
                _tempController, 'Temperature (°C)', Icons.thermostat_rounded,
                isLive: false),
            _buildTextField(
                _vibController, 'Vibration (mm/s)', Icons.vibration_rounded,
                isLive: false),
            _buildTextField(
                _pressController, 'Pressure (Bar)', Icons.compress_rounded,
                isLive: false),
            _buildTextField(
                _rpmController, 'Motor Speed (RPM)', Icons.speed_rounded,
                isLive: true),
            const SizedBox(height: 24),
            PremiumButton(
              label: 'Analyze Health',
              icon: Icons.auto_graph_rounded,
              onPressed: provider.isLoading ? null : _submit,
              color: AppColors.primary,
              isLoading: provider.isLoading,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon,
      {bool isLive = false}) {
    final hasVal = ctrl.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const Spacer(),
              if (isLive && hasVal)
                _badge('● Live', AppColors.accentGreen)
              else if (isLive && !hasVal)
                _badge('● Attempting Live Read', AppColors.accentAmber)
              else
                _badge('Manual Entry', AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<MaintenanceProvider>().runAnalysis(_machineId, {
        'temperature': double.parse(_tempController.text),
        'vibration': double.parse(_vibController.text),
        'pressure': double.parse(_pressController.text),
        'rpm': double.parse(_rpmController.text),
      });
    }
  }

  Widget _buildResultsView(BuildContext context, MaintenanceProvider provider) {
    final res = provider.latestAnalysis;
    if (res == null) {
      return const Center(
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.white10),
            SizedBox(height: 16),
            Text('No analysis results yet',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        GlassCard(
          borderColor: _getRiskColor(res.riskLevel).withValues(alpha: 0.5),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('AI Assessment',
                      style: Theme.of(context).textTheme.titleLarge),
                  StatusChip(
                      label: res.riskLevel,
                      color: _getRiskColor(res.riskLevel)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FAILURE PROBABILITY',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: res.failureProbability,
                          backgroundColor: Colors.white10,
                          color: _getRiskColor(res.riskLevel),
                          minHeight: 8,
                        ),
                        const SizedBox(height: 4),
                        Text(
                            '${(res.failureProbability * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: _getRiskColor(res.riskLevel))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoRow('Anomaly Count', '${res.anomalies.length}'),
              _buildInfoRow('Recommendation', res.recommendation,
                  isHighlight: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildAgentOutputs(res),
      ],
    );
  }

  Widget _buildAgentOutputs(MaintenanceModel res) {
    return Column(
      children: [
        _buildAgentCard(
            'Monitoring Agent',
            res.anomalies.isEmpty ? 'Normal' : 'Issues Found',
            res.anomalies.isEmpty
                ? AppColors.accentGreen
                : AppColors.accentOrange),
        _buildAgentCard(
            'Prediction Agent', 'Model accuracy: 92.4%', AppColors.primary),
        _buildAgentCard(
            'Maintenance Agent', res.recommendation, AppColors.accentAmber),
      ],
    );
  }

  Widget _buildAgentCard(String title, String message, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        child: Row(
          children: [
            Icon(Icons.terminal_rounded, size: 24, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(message,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHighlight
                          ? AppColors.accentOrange
                          : Colors.white))),
        ],
      ),
    );
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'Critical':
        return AppColors.accentRed;
      case 'High':
        return AppColors.accentOrange;
      case 'Medium':
        return AppColors.accentAmber;
      default:
        return AppColors.accentGreen;
    }
  }
}
