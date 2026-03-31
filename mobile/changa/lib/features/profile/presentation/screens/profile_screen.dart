import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    if (authState is! AuthAuthenticated) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      );
    }
    final user = authState.user;

    final initials = user.fullName
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    final avatarColors = [
      AppColors.forest,
      const Color(0xFF2D6A4F),
      const Color(0xFF1B4332),
      AppColors.mpesaGreen,
      const Color(0xFF52796F),
    ];
    final avatarColor =
        avatarColors[user.fullName.length % avatarColors.length];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.forest,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _ProfileBgPainter()),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        // Avatar with initials
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: avatarColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.cream.withValues(alpha: 0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: AppTextStyles.h2.copyWith(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w800,
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.mint),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.phone,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mint.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Stats ────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _StatsRow(userId: user.id)),

          // ── Menu ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader('Account'),
                  const SizedBox(height: 8),
                  _MenuCard(items: [
                    _MenuItem(
                      icon: Icons.person_outline,
                      label: 'Edit profile',
                      onTap: () => _showEditProfile(context, ref, user),
                    ),
                    _MenuItem(
                      icon: Icons.lock_outline,
                      label: 'Change password',
                      onTap: () => _showChangePassword(context, ref),
                    ),
                    _MenuItem(
                      icon: Icons.phone_android,
                      label: 'M-Pesa number',
                      value: user.phone,
                      onTap: () => _showEditPhone(context, ref, user.phone),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _SectionHeader('Preferences'),
                  const SizedBox(height: 8),
                  _MenuCard(items: [
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (_) {},
                        activeColor: AppColors.forest,
                      ),
                      onTap: null,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _SectionHeader('About'),
                  const SizedBox(height: 8),
                  _MenuCard(items: [
                    _MenuItem(
                      icon: Icons.info_outline,
                      label: 'App version',
                      value: '1.0.0',
                      onTap: null,
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy policy',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.description_outlined,
                      label: 'Terms of service',
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _LogoutButton(
                    onTap: () => _confirmLogout(context, ref),
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

  void _showEditProfile(BuildContext context, WidgetRef ref, dynamic user) {
    final nameCtrl = TextEditingController(text: user.fullName);
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BottomSheetHandle(),
              const SizedBox(height: 20),
              Text('Edit profile',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppColors.green),
                ),
                validator: (v) => v == null || v.trim().length < 2
                    ? 'Name is too short'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  // TODO: wire to update profile API
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(_snackBar('Profile updated'));
                },
                child: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BottomSheetHandle(),
              const SizedBox(height: 20),
              Text('Change password',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
              const SizedBox(height: 20),
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.green),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon:
                      Icon(Icons.lock_reset_outlined, color: AppColors.green),
                ),
                validator: (v) {
                  if (v == null || v.length < 8) return 'Min 8 characters';
                  if (!v.contains(RegExp(r'[A-Za-z]'))) return 'Must contain a letter';
                  if (!v.contains(RegExp(r'\d'))) return 'Must contain a number';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  // TODO: wire to change password API
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(_snackBar('Password changed successfully'));
                },
                child: const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditPhone(
      BuildContext context, WidgetRef ref, String currentPhone) {
    final phoneCtrl = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BottomSheetHandle(),
              const SizedBox(height: 20),
              Text('M-Pesa number',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
              const SizedBox(height: 4),
              Text('Used for all contributions',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.green)),
              const SizedBox(height: 20),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'M-Pesa number',
                  prefixIcon:
                      Icon(Icons.phone_android, color: AppColors.mpesaGreen),
                  hintText: '254712345678',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!RegExp(r'^254[17]\d{8}$').hasMatch(v)) {
                    return 'Use format 254XXXXXXXXX';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(_snackBar('M-Pesa number updated'));
                },
                child: const Text('Save number'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out',
            style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
        content: Text(
          'Are you sure you want to sign out of Changa?',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.green)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authNotifierProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  SnackBar _snackBar(String message) => SnackBar(
        content: Text(message),
        backgroundColor: AppColors.forest,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

// ── Stats row ──────────────────────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  final String userId;
  const _StatsRow({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsNotifierProvider);
    final myProjects =
        projectsState.projects.where((p) => p.ownerId == userId).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(value: '$myProjects', label: 'Projects\ncreated'),
          _VerticalDivider(),
          _StatItem(value: '0', label: 'Contributions\nmade'),
          _VerticalDivider(),
          _StatItem(value: 'KES 0', label: 'Total\ncontributed'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.green, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        width: 1,
        color: AppColors.sand.withValues(alpha: 0.5),
      );
}

// ── Helpers ────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

class _BottomSheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.sand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              _MenuTile(item: item),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.sand.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    required this.onTap,
  });
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.onTap != null
          ? () {
              HapticFeedback.selectionClick();
              item.onTap!();
            }
          : null,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.forest.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icon, color: AppColors.forest, size: 18),
      ),
      title: Text(item.label,
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.forest)),
      subtitle: item.value != null
          ? Text(item.value!,
              style: AppTextStyles.caption.copyWith(color: AppColors.green))
          : null,
      trailing: item.trailing ??
          (item.onTap != null
              ? const Icon(Icons.chevron_right,
                  color: AppColors.sand, size: 20)
              : null),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
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
    );
  }
}

class _ProfileBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width + 30, size.height * 0.2),
      120,
      Paint()..color = AppColors.sage.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(-40, size.height * 0.8),
      100,
      Paint()..color = AppColors.mint.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}