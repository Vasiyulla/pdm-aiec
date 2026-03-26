// ============================================================
//  connect_screen.dart  —  Device connection configuration
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _vfdPortCtrl = TextEditingController(text: 'COM7');
  final _pzemPortCtrl = TextEditingController(text: 'COM5');
  final _serverUrlCtrl = TextEditingController(text: 'http://localhost:8000');
  int _vfdBaud = 9600;
  int _pzemBaud = 9600;
  bool _simulate = false;
  bool _connectVfd = true;
  bool _connectPzem = true;
  List<String> _availablePorts = [];
  bool _portsLoading = false;

  @override
  void initState() {
    super.initState();
    final motor = context.read<MotorProvider>();
    _serverUrlCtrl.text = motor.serverUrl;
  }

  Future<void> _loadPorts() async {
    setState(() => _portsLoading = true);
    try {
      final ports = await context.read<MotorProvider>().api.getPorts();
      setState(() => _availablePorts = ports);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch ports: $e')),
        );
      }
    }
    setState(() => _portsLoading = false);
  }

  Future<void> _connect() async {
    final motor = context.read<MotorProvider>();
    motor.setServerUrl(_serverUrlCtrl.text.trim());

    final ok = await motor.connectDevices(
      vfdPort: _connectVfd ? _vfdPortCtrl.text.trim() : null,
      pzemPort: _connectPzem ? _pzemPortCtrl.text.trim() : null,
      vfdBaud: _vfdBaud,
      pzemBaud: _pzemBaud,
      simulate: _simulate,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Devices connected successfully!'),
      ));
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(motor.errorMsg ?? 'Connection failed'),
        backgroundColor: AppColors.accentRed,
      ));
    }
  }

  Future<void> _disconnect() async {
    await context.read<MotorProvider>().disconnectDevices();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Devices disconnected')),
    );
  }

  @override
  void dispose() {
    _vfdPortCtrl.dispose();
    _pzemPortCtrl.dispose();
    _serverUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorProvider>();
    final auth = context.watch<AuthProvider>();
    return AppShell(
      currentRoute: AppRouter.connect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _pageHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 480,
                    child: Column(
                      children: [
                        // Server config
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionTitle(context, Icons.dns_rounded, 'Backend Server'),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _serverUrlCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Server URL',
                                  hintText: 'http://localhost:8000',
                                  prefixIcon: Icon(Icons.link_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // VFD config
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _sectionTitle(context, Icons.settings_input_component_rounded, 'VFD (GD200A)'),
                                  const Spacer(),
                                  Switch(
                                    value: _connectVfd,
                                    onChanged: (v) => setState(() => _connectVfd = v),
                                    activeThumbColor: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_connectVfd) ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _vfdPortCtrl,
                                        enabled: _availablePorts.isEmpty,
                                        decoration: const InputDecoration(
                                          labelText: 'COM Port',
                                          hintText: 'COM7',
                                          prefixIcon: Icon(Icons.usb_rounded),
                                        ),
                                      ),
                                    ),
                                    if (_availablePorts.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: _vfdPortCtrl.text.isNotEmpty
                                              ? _vfdPortCtrl.text
                                              : null,
                                          items: _availablePorts.map((p) =>
                                            DropdownMenuItem(value: p, child: Text(p))
                                          ).toList(),
                                          onChanged: (v) => setState(() =>
                                              _vfdPortCtrl.text = v ?? ''),
                                          decoration: const InputDecoration(
                                            labelText: 'Select Port'),
                                          dropdownColor: AppColors.bg700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _vfdBaud,
                                  items: [9600, 19200, 38400, 57600, 115200]
                                      .map((b) => DropdownMenuItem(
                                          value: b, child: Text('$b baud')))
                                      .toList(),
                                  onChanged: (v) => setState(() => _vfdBaud = v ?? 9600),
                                  decoration: const InputDecoration(
                                    labelText: 'Baud Rate',
                                    prefixIcon: Icon(Icons.speed_rounded),
                                  ),
                                  dropdownColor: AppColors.bg700,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // PZEM config
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _sectionTitle(context, Icons.electrical_services_rounded, 'Power Meter (PZEM)'),
                                  const Spacer(),
                                  Switch(
                                    value: _connectPzem,
                                    onChanged: (v) => setState(() => _connectPzem = v),
                                    activeThumbColor: AppColors.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_connectPzem) ...[
                                TextField(
                                  controller: _pzemPortCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'COM Port',
                                    hintText: 'COM5',
                                    prefixIcon: Icon(Icons.usb_rounded),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _pzemBaud,
                                  items: [9600, 19200, 38400]
                                      .map((b) => DropdownMenuItem(
                                          value: b, child: Text('$b baud')))
                                      .toList(),
                                  onChanged: (v) => setState(() => _pzemBaud = v ?? 9600),
                                  decoration: const InputDecoration(
                                    labelText: 'Baud Rate',
                                    prefixIcon: Icon(Icons.speed_rounded),
                                  ),
                                  dropdownColor: AppColors.bg700,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Simulation mode
                        GlassCard(
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Simulation Mode',
                                    style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text('Run without real hardware',
                                    style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                              const Spacer(),
                              Switch(
                                value: _simulate,
                                onChanged: (v) => setState(() => _simulate = v),
                                activeThumbColor: AppColors.accentAmber,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  icon: _portsLoading
                                      ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: AppColors.primary),
                                        )
                                      : const Icon(Icons.search_rounded),
                                  label: const Text('Scan Ports'),
                                  onPressed: _portsLoading ? null : _loadPorts,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 50,
                                child: motor.deviceConnected
                                    ? ElevatedButton.icon(
                                        icon: const Icon(Icons.link_off_rounded),
                                        label: const Text('Disconnect All'),
                                        onPressed: auth.canOperate ? _disconnect : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.accentRed,
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        icon: motor.loading
                                            ? const SizedBox(
                                                width: 18, height: 18,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.link_rounded),
                                        label: const Text('Connect Devices'),
                                        onPressed:
                                            (motor.loading || !auth.canOperate)
                                                ? null
                                                : _connect,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Status panel
                  Expanded(child: _StatusPanel(motor: motor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeader(BuildContext context) {
    return Container(
      height: 64, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.bg900,
        border: Border(bottom: BorderSide(color: AppColors.bg600)),
      ),
      child: Row(
        children: [
          Text('Device Connection',
            style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final MotorProvider motor;
  const _StatusPanel({required this.motor});

  @override
  Widget build(BuildContext context) {
    final status = motor.status;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Connection Status', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    size: 18, color: AppColors.textSecondary),
                onPressed: motor.refreshStatus,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _statusRow(context, 'VFD Connected',
              status?.vfdConnected ?? false, Icons.settings_input_component_rounded),
          const SizedBox(height: 12),
          _statusRow(context, 'PZEM Connected',
              status?.pzemConnected ?? false, Icons.electrical_services_rounded),
          const SizedBox(height: 12),
          _statusRow(context, 'Simulation Mode',
              status?.simulationMode ?? false, Icons.science_rounded,
              activeColor: AppColors.accentAmber),
          const Divider(height: 32, color: AppColors.bg600),

          if (status != null) ...[
            _infoRow(context, 'Motor State', status.motorState),
            const SizedBox(height: 8),
            _infoRow(context, 'OC Threshold', '${status.ocThreshold.toStringAsFixed(1)} A'),
            const SizedBox(height: 8),
            _infoRow(context, 'WS Clients (Monitor)', '${status.wsMonitorClients}'),
            const SizedBox(height: 8),
            _infoRow(context, 'WS Clients (Alerts)', '${status.wsAlertClients}'),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No status data — connect first',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textMuted)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusRow(BuildContext context, String label, bool value,
      IconData icon, {Color? activeColor}) {
    final color = value ? (activeColor ?? AppColors.accentGreen) : AppColors.textMuted;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        const Spacer(),
        StatusChip(
          label: value ? 'Active' : 'Inactive',
          color: color,
          pulsing: value,
        ),
      ],
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) => Row(
    children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium),
      const Spacer(),
      Text(value,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.primary)),
    ],
  );
}
