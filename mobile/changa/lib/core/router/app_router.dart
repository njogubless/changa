import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/auth/presentation/screens/login_screen.dart';
import 'package:changa/features/auth/presentation/screens/register_screen.dart';
import 'package:changa/features/budget/presentation/screens/budget_screen..dart';
import 'package:changa/features/chama/presentation/screens/chama_detail_screen.dart';
import 'package:changa/features/chama/presentation/screens/chama_homescreen.dart';
import 'package:changa/features/chama/presentation/screens/create_join_chama_screen.dart';
import 'package:changa/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:changa/features/payments/presentation/screens/payment_screen.dart';
import 'package:changa/features/payments/presentation/screens/payment_status_screen.dart';
import 'package:changa/features/profile/presentation/screens/profile_screen.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/screens/all_projects_screen.dart';

import 'package:changa/features/projects/presentation/screens/create_screen.dart';
import 'package:changa/features/projects/presentation/screens/edit_project_screen.dart';
import 'package:changa/features/projects/presentation/screens/project_detail_screen.dart';

import 'package:changa/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shell_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const profile = '/profile';
  static const allProjects = '/projects';
  static const budget = '/budget';

  // Chamas
  static const chamaDetail = '/chamas/:id';
  static const createChama = '/chamas/create';
  static const joinChama = '/chamas/join';
  static String chamaDetailPath(String id) => '/chamas/$id';

  // Projects
  static const projectDetail = '/projects/:id';
  static const createProject = '/chamas/:chamaId/projects/create';
  static String projectDetailPath(String id) => '/projects/$id';
  static String createProjectPath(String chamaId) =>
      '/chamas/$chamaId/projects/create';

  // Payments
  static const payment = '/payment';
  static const paymentStatus = '/payment/status';
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
      final currentPath = state.matchedLocation;

      if (isInitial || isLoading) return AppRoutes.splash;

      final authRoutes = [
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.onboarding,
        AppRoutes.splash,
      ];

      if (isAuthenticated) {
        if (authRoutes.contains(currentPath)) return AppRoutes.home;
        return null;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('onboarding_done') ?? false;
        if (currentPath == AppRoutes.onboarding) return null;
        if (!seenOnboarding) return AppRoutes.onboarding;
        if (!authRoutes.contains(currentPath)) return AppRoutes.login;
        return null;
      }
    },
    routes: [
      GoRoute(
          path: AppRoutes.splash,
          builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: AppRoutes.onboarding,
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: AppRoutes.register,
          builder: (_, __) => const RegisterScreen()),

      // ── Shell (bottom nav: Home, Projects, Budget) ──────────────────
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const ChamasHomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.allProjects,
            builder: (_, __) => const AllProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.budget,
            builder: (_, __) => const BudgetScreen(),
          ),
        ],
      ),

      // ── Profile (pushed from drawer, no bottom nav) ─────────────────
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),

      // ── Chama routes ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.createChama,
        builder: (_, __) => const CreateChamaScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinChama,
        builder: (_, __) => const JoinChamaScreen(),
      ),
      GoRoute(
        path: AppRoutes.chamaDetail,
        builder: (_, state) =>
            ChamaDetailScreen(chamaId: state.pathParameters['id']!),
      ),

      // ── Project routes ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.createProject,
        builder: (_, state) => CreateProjectScreen(
          chamaId: state.pathParameters['chamaId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.projectDetail,
        builder: (_, state) =>
            ProjectDetailScreen(projectId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/projects/:id/edit',
        builder: (_, state) =>
            EditProjectScreen(project: state.extra as ProjectModel),
      ),

      // ── Payment routes ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.payment,
        builder: (_, state) => PaymentScreen(
          projectId: state.uri.queryParameters['project_id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentStatus,
        builder: (_, state) => PaymentStatusScreen(
          reference: state.uri.queryParameters['ref']!,
          amount:
              double.parse(state.uri.queryParameters['amount'] ?? '0'),
        ),
      ),
    ],
  );
});