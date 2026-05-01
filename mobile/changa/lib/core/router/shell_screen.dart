// shell_screen.dart
import 'package:changa/core/router/app_drawer.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';

// ── Moved key to a StatefulWidget wrapper so it lives across rebuilds ──
class ShellScreen extends StatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  // Key lives in State — survives widget rebuilds
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _locationToIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/projects')) return 1;
    if (location.startsWith('/budget')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _locationToIndex(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.cream,
      // Drawer is isolated — only rebuilds when user changes, not whole shell
      drawer: _DrawerConsumer(scaffoldKey: _scaffoldKey),
      body: ColoredBox(
        color: AppColors.cream,
        child: widget.child,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: currentIndex,
        onTap: (i) {
          switch (i) {
            case 0: context.go(AppRoutes.home);
            case 1: context.go(AppRoutes.allProjects);
            case 2: context.go(AppRoutes.budget);
          }
        },
      ),
    );
  }
}

// Isolated consumer — only this rebuilds when user changes, not the whole shell
class _DrawerConsumer extends ConsumerWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  const _DrawerConsumer({required this.scaffoldKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AppDrawer(user: user, scaffoldKey: scaffoldKey);
  }
}

// Stateless — NavigationBar never rebuilds unless currentIndex changes
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.transparent,
      indicatorColor: AppColors.forest.withValues(alpha: 0.1),
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: AppColors.forest),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder, color: AppColors.forest),
          label: 'Projects',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart, color: AppColors.forest),
          label: 'Budget',
        ),
      ],
    );
  }
}