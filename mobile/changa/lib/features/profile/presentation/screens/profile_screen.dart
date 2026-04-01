import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/profile/presentation/widgets/profile_header.dart';
import 'package:changa/features/profile/presentation/widgets/profile_menu.dart';
import 'package:changa/features/profile/presentation/widgets/profile_sheets.dart';
import 'package:changa/features/profile/presentation/widgets/profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
      );
    }

    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.forest,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: ProfileHeader(user: user),
            ),
          ),

          // ── Stats ──────────────────────────────────────────────────────
          SliverToBoxAdapter(child: ProfileStatsRow(userId: user.id)),

          // ── Menu sections ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ProfileSectionHeader('Account'),
                  const SizedBox(height: 8),
                  ProfileMenuCard(items: [
                    ProfileMenuTileData(
                      icon: Icons.person_outline,
                      label: 'Edit profile',
                      onTap: () =>
                          showEditProfileSheet(context, ref, user.fullName),
                    ),
                    ProfileMenuTileData(
                      icon: Icons.lock_outline,
                      label: 'Change password',
                      onTap: () => showChangePasswordSheet(context, ref),
                    ),
                    ProfileMenuTileData(
                      icon: Icons.phone_android,
                      label: 'M-Pesa number',
                      value: user.phone,
                      onTap: () =>
                          showEditPhoneSheet(context, ref, user.phone),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const ProfileSectionHeader('Preferences'),
                  const SizedBox(height: 8),
                  ProfileMenuCard(items: [
                    ProfileMenuTileData(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (_) {},
                        activeThumbColor: AppColors.forest,
                      ),
                      onTap: null,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const ProfileSectionHeader('About'),
                  const SizedBox(height: 8),
                  ProfileMenuCard(items: const [
                    ProfileMenuTileData(
                      icon: Icons.info_outline,
                      label: 'App version',
                      value: '1.0.0',
                      onTap: null,
                    ),
                    ProfileMenuTileData(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      onTap: null,
                    ),
                    ProfileMenuTileData(
                      icon: Icons.description_outlined,
                      label: 'Terms of service',
                      onTap: null,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  ProfileLogoutButton(
                    onTap: () => showLogoutDialog(context, ref),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
