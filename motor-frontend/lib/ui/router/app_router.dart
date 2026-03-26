import 'package:flutter/material.dart';
import 'package:motor_frontend/ui/screens/splash_screen.dart';
import 'package:motor_frontend/ui/screens/login_screen.dart';
import 'package:motor_frontend/ui/screens/dashboard_screen.dart';
import 'package:motor_frontend/ui/screens/connect_screen.dart';
import 'package:motor_frontend/ui/screens/alerts_screen.dart';
import 'package:motor_frontend/ui/screens/history_screen.dart';
import 'package:motor_frontend/ui/screens/settings_screen.dart';
import 'package:motor_frontend/ui/screens/logs_screen.dart';
import 'package:motor_frontend/ui/screens/monitor_screen.dart';
import 'package:motor_frontend/ui/screens/maintenance/dashboard_screen.dart';
import 'package:motor_frontend/ui/screens/maintenance/run_analysis_screen.dart';
import 'package:motor_frontend/ui/screens/maintenance/machine_detail_screen.dart';

class AppRouter {
  static const splash = '/splash';
  static const login = '/login';
  static const dashboard = '/';
  static const connect = '/connect';
  static const monitor = '/monitor';
  static const alerts = '/alerts';
  static const logs = '/logs';
  static const history = '/history';
  static const settings = '/settings';
  static const maintenance = '/maintenance';
  static const maintenanceAnalyze = '/maintenance/analyze';
  static const maintenanceDetail = '/maintenance/detail';

  static Route<dynamic> generateRoute(RouteSettings settings_) {
    switch (settings_.name) {
      case splash:
        return _fade(const SplashScreen());
      case login:
        return _fade(const LoginScreen());
      case dashboard:
        return _fade(const DashboardScreen());
      case connect:
        return _fade(const ConnectScreen());
      case monitor:
        return _fade(const MonitorScreen());
      case alerts:
        return _fade(const AlertsScreen());
      case logs:
        return _fade(const LogsScreen());
      case history:
        return _fade(const HistoryScreen());
      case settings:
        return _fade(const SettingsScreen());
      case maintenance:
        return _fade(const MaintenanceDashboard());
      case maintenanceAnalyze:
        return _fade(const RunAnalysisScreen());
      case maintenanceDetail:
        final id = settings_.arguments as String? ?? 'M-001';
        return _fade(MachineDetailScreen(machineId: id));
      default:
        return _fade(const LoginScreen());
    }
  }

  static PageRouteBuilder _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }
}
