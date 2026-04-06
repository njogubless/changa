import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChamasHomeScreen extends ConsumerWidget {
  const ChamasHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chamaListProvider);
    final user = ref.watch(currentUserProvider);
    final firstName = user?.fullName.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: AppColors.cream,
      // ── Hamburger opens the drawer ──────────────────────────────────
      drawer: null, // drawer is on ShellScreen, trigger it from there
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => ref.read(chamaListProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 130,
              floating: true,
              snap: true,
              pinned: false,
              backgroundColor: AppColors.forest,
              automaticallyImplyLeading: false,
              leading: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.cream),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.forest,
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        firstName.isNotEmpty
                            ? 'Habari, $firstName 👋'
                            : 'Habari 👋',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.mint),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Chamas',
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.cream,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Join / Create — always visible at top ─────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _PrimaryAction(
                        icon: Icons.group_add_outlined,
                        label: 'Join Chama',
                        onTap: () => context.push('/chamas/join'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PrimaryAction(
                        icon: Icons.add_circle_outline,
                        label: 'Create Chama',
                        onTap: () => context.push('/chamas/create'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────
            if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.forest,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (state.error != null)
              SliverFillRemaining(
                child: _ErrorState(
                  onRetry: () =>
                      ref.read(chamaListProvider.notifier).refresh(),
                ),
              )
            else if (state.chamas.isEmpty)
              const SliverFillRemaining(child: _EmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ChamaCard(chama: state.chamas[i]),
                    ),
                    childCount: state.chamas.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Primary action buttons (Join / Create) ─────────────────────────────────
class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.cream, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Chama card ─────────────────────────────────────────────────────────────
class _ChamaCard extends StatelessWidget {
  final ChamaModel chama;
  const _ChamaCard({required this.chama});

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.forest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(chama.avatarColor);
    final initials = chama.name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: () => context.push('/chamas/${chama.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chama.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Chip(
                        icon: Icons.people_outline,
                        label: '${chama.memberCount} members',
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        icon: Icons.folder_outlined,
                        label: '${chama.activeProjectCount} active',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.sand, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 12, color: AppColors.green),
          const SizedBox(width: 3),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: AppColors.green)),
        ],
      );
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.sage.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_outline,
                    color: AppColors.forest, size: 36),
              ),
              const SizedBox(height: 20),
              Text('No Chamas yet',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
              const SizedBox(height: 8),
              Text(
                'Use the buttons above to create\nor join a Chama.',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.green),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── Error state ────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined,
                  color: AppColors.sand, size: 48),
              const SizedBox(height: 16),
              Text('Could not load Chamas',
                  style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
}