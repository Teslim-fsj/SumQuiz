import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Combine min splash duration with initialization
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final authService = Provider.of<AuthService>(context, listen: false);

    final user = authService.currentUser;
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      context.go('/onboarding');
    } else if (user == null) {
      context.go('/auth');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gradient definitions
    final colors1 = [
      const Color(0xFF1A237E),
      const Color(0xFF3949AB)
    ]; // Deep Blue
    final colors2 = [
      const Color(0xFF311B92),
      const Color(0xFF5E35B1)
    ]; // Deep Purple

    return Scaffold(
      body: Animate(
        onPlay: (controller) => controller.repeat(reverse: true),
        effects: [
          CustomEffect(
            duration: 4.seconds,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(colors1[0], colors2[0], value)!,
                      Color.lerp(colors1[1], colors2[1], value)!,
                    ],
                  ),
                ),
                child: child,
              );
            },
          )
        ],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing Logo
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32.0),
                child: Image.asset(
                  'assets/images/sumquiz_logo.png',
                  width: 100,
                  height: 100,
                ),
              )
                  .animate(
                      onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    duration: 1.5.seconds,
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    curve: Curves.easeInOut,
                  )
                  .then() // Connecting animation
                  .shimmer(
                      duration: 2.seconds,
                      color: Colors.white.withOpacity(0.5)),

              const SizedBox(height: 48),

              // Title "Sum"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sum',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 2,
                        ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms)
                      .moveX(begin: -20, end: 0),

                  // Title "Quiz"
                  Text(
                    'Quiz',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                  )
                      .animate()
                      .fadeIn(duration: 800.ms, delay: 300.ms)
                      .moveX(begin: 20, end: 0),
                ],
              ),

              const SizedBox(height: 16),

              // Tagline tyewriter
              Text(
                'Unlock your potential',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      letterSpacing: 1.5,
                    ),
              )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 800.ms)
                  .slideY(begin: 0.5, end: 0),

              const SizedBox(height: 64),

              // Loading indicator
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white54, strokeWidth: 2),
              ).animate().fadeIn(delay: 1.5.seconds),
            ],
          ),
        ),
      ),
    );
  }
}
