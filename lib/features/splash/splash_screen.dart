import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final restore = ref.read(authProvider.notifier).restoreSession();
    await Future.wait([
      restore,
      Future<void>.delayed(const Duration(milliseconds: 2200)),
    ]);
    if (!mounted) return;
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    context.go(isAuthenticated ? '/home' : '/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: child,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 220,
                    height: 110,
                    child: Center(
                      child: AppLogo(size: 78, gap: 12),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'RPV Workforce',
                    style: TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Employee Management System',
                    style: TextStyle(
                      color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            AppColors.secondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'chiukim.com',
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withValues(alpha: 0.4),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
