import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:motor_frontend/core/theme/app_theme.dart';
import 'package:motor_frontend/core/services/auth_service.dart';
import 'package:motor_frontend/core/services/api_service.dart';
import 'package:motor_frontend/core/services/motor_ws_isolate.dart';
import 'package:motor_frontend/core/providers/motor_provider.dart';
import 'package:motor_frontend/ui/widgets/motor_data_notifiers.dart';
import 'package:motor_frontend/core/providers/auth_provider.dart';
import 'package:motor_frontend/core/providers/theme_provider.dart';
import 'package:motor_frontend/core/providers/maintenance_provider.dart';
import 'package:motor_frontend/ui/router/app_router.dart';

final _notifiers = MotorDataNotifiers();
final _bridge = MotorWsIsolateBridge();
// Don't start the isolate yet — start it when user connects to a server.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setApplicationSwitcherDescription(
    const ApplicationSwitcherDescription(
      label: 'Motor Dashboard — Predictive Maintenance',
    ),
  );

  runApp(const MotorDashboardApp());
}

class MotorDashboardApp extends StatelessWidget {
  const MotorDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService())),
        Provider<MotorDataNotifiers>.value(value: _notifiers),
        Provider<MotorWsIsolateBridge>.value(value: _bridge),
        ChangeNotifierProvider(
          create: (_) => MotorProvider(ApiService(), _bridge, _notifiers),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MaintenanceProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Motor Dashboard',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: AppRouter.splash,
          );
        },
      ),
    );
  }
}
