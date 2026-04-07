import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/data/models/auth_models.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppDrawer extends ConsumerWidget {
  final UserModel? user;
  const AppDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = (user?.fullName ?? 'U')
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return Drawer(
      backgroundColor: AppColors.cream,
      child: SafeArea(
        child: Column(
          children: [
            // ── User header ────────────────────────────────────────────
            _DrawerHeader(
              initials: initials,
              userName: user?.fullName ?? '',
              userEmail: user?.email ?? '',
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),

            const SizedBox(height: 8),

            // ── Menu ──────────────────────────────────────────────────
            _DrawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                // TODO: settings screen
              },
            ),
            _DrawerItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.pop(context),
            ),
            _DrawerItem(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => Navigator.pop(context),
            ),

            const Spacer(),

            // ── Logout ────────────────────────────────────────────────
            _DrawerLogout(
              onTap: () {
                Navigator.pop(context);
                ref.read(authNotifierProvider.notifier).logout();
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  final String initials;
  final String userName;
  final String userEmail;
  final VoidCallback onTap;

  const _DrawerHeader({
    required this.initials,
    required this.userName,
    required this.userEmail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          color: AppColors.forest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.sage.withValues(alpha: 0.3),
                child: Text(
                  initials,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                userName,
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userEmail,
                style: AppTextStyles.caption.copyWith(color: AppColors.mint),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'View profile',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.mint,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: AppColors.mint, size: 14),
                ],
              ),
            ],
          ),
        ),
      );
}

// ── Menu item ──────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.forest.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.forest, size: 18),
        ),
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.sand, size: 18),
        onTap: onTap,
      );
}

// ── Logout button ──────────────────────────────────────────────────────────
class _DrawerLogout extends StatelessWidget {
  final VoidCallback onTap;
  const _DrawerLogout({required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Sign out',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}