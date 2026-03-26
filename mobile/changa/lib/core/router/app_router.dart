// ignore_for_file: unnecessary_underscores

import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/auth/presentation/screens/login_screen.dart';
import 'package:changa/features/auth/presentation/screens/register_screen.dart';
import 'package:changa/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:changa/features/payments/presentation/screens/payment_screen.dart';
import 'package:changa/features/payments/presentation/screens/payment_status_screen.dart';
import 'package:changa/features/profile/presentation/screens/profile_screen.dart';
import 'package:changa/features/projects/presentation/screens/create_project_screen.dart';
import 'package:changa/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:changa/features/projects/presentation/screens/projects_list_screen.dart';
import 'package:changa/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell_screen.dart';

// Route names
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const projects = '/projects';
  static const createProject = '/projects/create';
  static const projectDetail = '/projects/:id';
  static const payment = '/payment';
  static const paymentStatus = '/payment/status';
  static const profile = '/profile';

  // Helper to build project detail path
  static String projectDetailPath(String id) => '/projects/$id';
  // Helper to build payment path
  static String paymentPath(String projectId) =>
      '/payment?project_id=$projectId';
  static String paymentStatusPath(String ref, double amount) =>
      '/payment/status?ref=$ref&amount=$amount';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) async {
      final isAuthenticated = authState is AuthAuthenticated;
      final isInitial = authState is AuthInitial;
      final isLoading = authState is AuthLoading;

      // Still checking session — stay on splash
      if (isInitial) return AppRoutes.splash;

      // no redirect
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),

      // Shell — bottom nav wrapper
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const ProjectsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.projects,
            builder: (_, __) => const ProjectsListScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // Full-screen routes (no bottom nav)
      GoRoute(
        path: AppRoutes.createProject,
        builder: (_, __) => const CreateProjectScreen(),
      ),
      GoRoute(
        path: AppRoutes.projectDetail,
        builder:
            (_, state) =>
                ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),

      GoRoute(
        path: AppRoutes.payment,
        builder:
            (_, state) => PaymentScreen(
              projectId: state.uri.queryParameters['project_id']!,
            ),
      ),
      GoRoute(
        path: AppRoutes.paymentStatus,
        builder:
            (_, state) => PaymentStatusScreen(
              reference: state.uri.queryParameters['ref']!,
              amount: double.parse(state.uri.queryParameters['amount'] ?? '0'),
            ),
      ),
    ],
  );
});
