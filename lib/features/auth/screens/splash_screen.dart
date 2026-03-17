/// SmartDiet AI - Splash Screen
/// 
/// Initial loading screen that checks authentication state.
library;

import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/services/supabase_service.dart';
import 'package:smart_diet_ai/core/theme/clay_theme.dart';
import 'package:smart_diet_ai/features/auth/screens/login_screen.dart';
import 'package:smart_diet_ai/features/dashboard/screens/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait a moment to show splash screen
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Navigate based on auth state
    if (SupabaseService.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ClayColors.primary,
              ClayColors.primaryDeep,
              ClayColors.primary,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo — clay raised style
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: ClayColors.surface,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: ClayColors.primaryDeep.withValues(alpha: 0.5),
                      offset: const Offset(8, 8),
                      blurRadius: 20,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      offset: const Offset(-6, -6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  size: 64,
                  color: ClayColors.primary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'SmartDiet AI',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI-Powered Nutrition Partner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
