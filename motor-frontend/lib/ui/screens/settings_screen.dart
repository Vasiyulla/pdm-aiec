// ============================================================
//  settings_screen.dart  —  App configuration & preferences
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/glass_card.dart';
import '../router/app_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _ocCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final motor = context.read<MotorProvider>();
    _urlCtrl = TextEditingController(text: motor.serverUrl);
    _ocCtrl = TextEditingController(
      text: (motor.status?.ocThreshold ?? 10.0).toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _ocCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final motor = context.read<MotorProvider>();
    motor.setServerUrl(_urlCtrl.text.trim());

    final oc = double.tryParse(_ocCtrl.text);
    if (oc != null) {
      await motor.api.setOcThreshold(oc);
    }

    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorProvider>();
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return AppShell(
      currentRoute: AppRouter.settings,
      child: Column(
        children: [
          // Header
          Container(
            height: 64, padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.bg900 : AppColors.lightSurface,
              border: Border(
                  bottom: BorderSide(
                      color: isDark ? AppColors.bg600 : AppColors.lightBorder)),
            ),
            child: Row(
              children: [
                Text('Settings', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),

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
                        // Appearance
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sTitle(context, Icons.palette_outlined, 'Appearance'),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _themeOption(
                                    context,
                                    'Light',
                                    Icons.light_mode_rounded,
                                    themeProvider.themeMode == ThemeMode.light,
                                    () => themeProvider.setThemeMode(ThemeMode.light),
                                  ),
                                  const SizedBox(width: 12),
                                  _themeOption(
                                    context,
                                    'Dark',
                                    Icons.dark_mode_rounded,
                                    themeProvider.themeMode == ThemeMode.dark,
                                    () => themeProvider.setThemeMode(ThemeMode.dark),
                                  ),
                                  const SizedBox(width: 12),
                                  _themeOption(
                                    context,
                                    'System',
                                    Icons.settings_suggest_rounded,
                                    themeProvider.themeMode == ThemeMode.system,
                                    () => themeProvider.setThemeMode(ThemeMode.system),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Server
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sTitle(context, Icons.dns_rounded, 'Backend Server'),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _urlCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'API Server URL',
                                  prefixIcon: Icon(Icons.link_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Protection
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sTitle(context, Icons.security_rounded, 'Motor Protection'),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _ocCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Overcurrent Threshold (A)',
                                  hintText: '10.0',
                                  prefixIcon: Icon(Icons.warning_amber_rounded),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Motor will trigger an over-current alert when '
                                'current exceeds this value.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              _saved
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.save_rounded,
                            ),
                            label: Text(_saved ? 'Saved!' : 'Save Settings'),
                            onPressed: auth.isAdmin ? _save : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _saved
                                  ? AppColors.accentGreen
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        if (!auth.isAdmin) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.accentAmber.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded,
                                    size: 14, color: AppColors.accentAmber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admin role required to modify settings.',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                      fontSize: 12,
                                      color: AppColors.accentAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Account info
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sTitle(context, Icons.account_circle_outlined, 'Account'),
                          const SizedBox(height: 20),
                          _infoRow(context, 'Username', auth.user?.username ?? '—'),
                          const SizedBox(height: 12),
                          _infoRow(context, 'Role', auth.user?.role ?? '—'),
                          const SizedBox(height: 12),
                          _infoRow(context, 'Permissions',
                            auth.isAdmin
                                ? 'Full access (admin)'
                                : auth.canOperate
                                    ? 'Motor control (operator)'
                                    : 'Read only (viewer)'),
                          const Divider(height: 32, color: AppColors.bg600),
                          _sTitle(context, Icons.info_outline_rounded, 'System Info'),
                          const SizedBox(height: 16),
                          _infoRow(context, 'App Version', '1.0.0'),
                          const SizedBox(height: 8),
                          _infoRow(context, 'Backend', motor.serverUrl),
                          const SizedBox(height: 8),
                          _infoRow(context, 'Motor State', motor.motorState),
                          const SizedBox(height: 8),
                          _infoRow(context, 'Simulation',
                              motor.status?.simulationMode == true ? 'Yes' : 'No'),
                          const Divider(height: 32, color: AppColors.bg600),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Sign Out'),
                              onPressed: () async {
                                final auth = context.read<AuthProvider>();
                                await motor.disconnectDevices();
                                await auth.logout();
                                if (!context.mounted) return;
                                Navigator.pushReplacementNamed(
                                    context, AppRouter.login);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accentRed,
                                side: const BorderSide(color: AppColors.accentRed),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _themeOption(BuildContext context, String label, IconData icon,
          bool selected, VoidCallback onTap) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 20,
                    color: selected ? AppColors.primary : AppColors.lightTextMuted),
                const SizedBox(height: 8),
                Text(label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 12,
                          color: selected
                              ? AppColors.primary
                              : AppColors.lightTextMuted,
                        )),
              ],
            ),
          ),
        ),
      );

  Widget _sTitle(BuildContext context, IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleMedium),
    ],
  );

  Widget _infoRow(BuildContext context, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 120,
        child: Text(label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textMuted)),
      ),
      Expanded(
        child: Text(value,
          style: Theme.of(context).textTheme.bodyLarge),
      ),
    ],
  );
}
