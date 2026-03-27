// ============================================================
//  login_screen.dart  —  Professional login with animations
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../router/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_userCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (ok) {
      Navigator.pushReplacementNamed(context, AppRouter.dashboard);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.accentRed),
              const SizedBox(width: 10),
              Text(auth.error ?? 'Login failed'),
            ],
          ),
          backgroundColor: isDark ? AppColors.bg700 : AppColors.lightTextPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.bg900 : AppColors.lightBg,
      body: Stack(
        children: [
          // Background gradient blobs
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 500, height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -80,
            child: Container(
              width: 400, height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.accent.withValues(alpha: 0.1),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Login panel
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Left branding panel
                    if (size.width > 900) ...[
                      SizedBox(
                        width: 420,
                        child: Padding(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 72, height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                  ),
                                  boxShadow: [BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.4),
                                    blurRadius: 30, spreadRadius: 5,
                                  )],
                                ),
                                child: const Icon(Icons.settings_suggest_rounded,
                                    size: 36, color: Colors.white),
                              ),
                              const SizedBox(height: 28),
                              Text('Motor Dashboard',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  foreground: Paint()
                                    ..shader = const LinearGradient(
                                      colors: [AppColors.primary, AppColors.primaryLight],
                                    ).createShader(const Rect.fromLTWH(0, 0, 300, 40)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Predictive Maintenance & Control\nSystem for INVT GD200A VFD',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              const SizedBox(height: 40),
                              _buildFeatureRow(Icons.bolt_rounded, 'Real-time VFD monitoring'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(Icons.analytics_rounded, 'Historical trend analysis'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(Icons.notifications_active_rounded, 'Smart alert engine'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(Icons.shield_rounded, 'Role-based access control'),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1, height: 400,
                        color: isDark ? AppColors.bg500 : AppColors.lightBorder,
                      ),
                    ],

                    // Login form
                    SizedBox(
                      width: 420,
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Welcome Back',
                              style: Theme.of(context).textTheme.displayMedium),
                            const SizedBox(height: 6),
                            Text('Sign in to your account',
                              style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 36),
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _userCtrl,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      labelText: 'Username',
                                      prefixIcon: Icon(Icons.person_outline_rounded,
                                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                                    ),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Required' : null,
                                    onFieldSubmitted: (_) => _login(),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: _obscure,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: Icon(Icons.lock_outline_rounded,
                                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
                                        ),
                                        onPressed: () =>
                                            setState(() => _obscure = !_obscure),
                                      ),
                                    ),
                                    validator: (v) =>
                                        v == null || v.isEmpty ? 'Required' : null,
                                    onFieldSubmitted: (_) => _login(),
                                  ),
                                  const SizedBox(height: 28),
                                  Consumer<AuthProvider>(
                                    builder: (_, auth, __) => SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: auth.loading ? null : _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: auth.loading
                                            ? const SizedBox(
                                                width: 22, height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Sign In',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                )),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Demo credentials hint
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded,
                                          size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Text('Demo Credentials',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(color: AppColors.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _credHint('admin', 'admin123', 'Full access', isDark),
                                  _credHint('operator', 'op@2024', 'Motor control', isDark),
                                  _credHint('viewer', 'view123', 'Read-only', isDark),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      Text(text, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );

  Widget _credHint(String user, String pass, String role, bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: RichText(
      text: TextSpan(
        style: TextStyle(
            fontSize: 12, 
            color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary),
        children: [
          TextSpan(
            text: '$user / $pass',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.lightTextPrimary,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
          TextSpan(text: '  —  $role'),
        ],
      ),
    ),
  );
}
