// ============================================================
//  splash_screen.dart  —  Boot screen with auth check
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../router/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    // Wait for auth init
    while (auth.status == AuthStatus.unknown) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    if (auth.status == AuthStatus.authenticated) {
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    } else {
      Navigator.pushReplacementNamed(context, AppRouter.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.bg900 : AppColors.lightBg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.settings_suggest_rounded,
                      size: 60, color: Colors.white),
                ),
                const SizedBox(height: 32),
                Text(
                  'Motor Dashboard',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ).createShader(const Rect.fromLTWH(0, 0, 280, 40)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Predictive Maintenance System',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondary
                            : AppColors.lightTextSecondary,
                      ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: isDark ? AppColors.bg600 : AppColors.lightBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Initializing system…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
