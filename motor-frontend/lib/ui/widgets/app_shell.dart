// ============================================================
//  app_shell.dart  —  Persistent sidebar + content layout
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/motor_provider.dart';
import '../../core/theme/app_theme.dart';
import '../router/app_router.dart';
import 'aria_chatbot.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  static const _navItems = [
    _NavItem(AppRouter.dashboard, Icons.dashboard_rounded, 'Motor Dashboard'),
    _NavItem(AppRouter.connect, Icons.cable_rounded, 'VFD Connect'),
    _NavItem(AppRouter.monitor, Icons.monitor_heart_rounded, 'Live Monitor'),
    _NavItem(AppRouter.alerts, Icons.notifications_rounded, 'System Alerts'),
    _NavItem(AppRouter.logs, Icons.receipt_long_rounded, 'Event Logs'),
    _NavItem(AppRouter.history, Icons.history_rounded, 'Data History'),
    _NavItem(AppRouter.maintenance, Icons.psychology_rounded, 'AI Maintenance'),
    _NavItem(AppRouter.maintenanceAnalyze, Icons.analytics_rounded, 'Run Analysis'),
    _NavItem(AppRouter.settings, Icons.settings_rounded, 'App Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final motor = context.watch<MotorProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bg800 : AppColors.lightBg,
      body: Stack(
        children: [
          Row(
            children: [
              // ── Sidebar ──────────────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: _sidebarCollapsed ? 68 : 240,
                color: isDark ? AppColors.bg900 : AppColors.lightSurface,
                child: Column(
                  children: [
                    // Logo / toggle
                    Container(
                      height: 64,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? AppColors.bg600 : AppColors.lightBorder,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.gradientPrimary,
                            ),
                            child: const Icon(Icons.settings_suggest_rounded,
                                size: 20, color: Colors.white),
                          ),
                          if (!_sidebarCollapsed) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('MotorDash',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          IconButton(
                            icon: Icon(
                              _sidebarCollapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
    
                    // Motor status badge
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: EdgeInsets.symmetric(
                        horizontal: _sidebarCollapsed ? 0 : 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _motorStatusColor(motor.motorState).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _motorStatusColor(motor.motorState).withValues(alpha: 0.3),
                        ),
                      ),
                      child: _sidebarCollapsed
                          ? Center(
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _motorStatusColor(motor.motorState),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _motorStatusColor(motor.motorState),
                                    boxShadow: [BoxShadow(
                                      color: _motorStatusColor(motor.motorState),
                                      blurRadius: 6,
                                    )],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Motor: ${motor.motorState}',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _motorStatusColor(motor.motorState),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
    
                    // Navigation items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: _navItems.map((item) {
                          final isActive = widget.currentRoute == item.route;
                          final hasAlert = item.route == AppRouter.alerts &&
                              motor.activeAlerts.isNotEmpty;
    
                          return Tooltip(
                            message: _sidebarCollapsed ? item.label : '',
                            preferBelow: false,
                            child: InkWell(
                              onTap: () => Navigator.pushReplacementNamed(
                                  context, item.route),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.primary.withValues(alpha: 0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Stack(
                                      children: [
                                        Icon(item.icon,
                                          size: 20,
                                          color: isActive
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        if (hasAlert)
                                          Positioned(
                                            right: 0, top: 0,
                                            child: Container(
                                              width: 7, height: 7,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.accentRed,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (!_sidebarCollapsed) ...[
                                      const SizedBox(width: 12),
                                      Text(item.label,
                                        style: Theme.of(context).textTheme.bodyLarge
                                            ?.copyWith(
                                          color: isActive
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                          fontWeight: isActive
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
    
                    // User info + logout
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.bg600 : AppColors.lightBorder,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                            child: Text(
                              (auth.user?.username ?? '?')[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (!_sidebarCollapsed) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(auth.user?.username ?? '',
                                    style: Theme.of(context).textTheme.labelLarge
                                        ?.copyWith(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(auth.user?.role ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () => _logout(context),
                              tooltip: 'Sign out',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ] else
                            IconButton(
                              icon: const Icon(Icons.logout_rounded,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () => _logout(context),
                              tooltip: 'Sign out',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    
              // ── Main content ──────────────────────────────────────────
              Expanded(child: widget.child),
            ],
          ),
          const AriaChatbot(),
        ],
      ),
    );
  }

  Color _motorStatusColor(String state) {
    switch (state) {
      case 'FWD':
      case 'REV':
        return AppColors.statusRunning;
      case 'FAULT':
        return AppColors.statusFault;
      default:
        return AppColors.statusStopped;
    }
  }

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final motor = context.read<MotorProvider>();
    await motor.disconnectDevices();
    await auth.logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }
}

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  const _NavItem(this.route, this.icon, this.label);
}
