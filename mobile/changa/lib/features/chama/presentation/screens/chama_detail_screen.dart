import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/chamas/data/models/chama_models.dart';
import 'package:changa/features/chamas/presentation/providers/chama_provider.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChamaDetailScreen extends ConsumerWidget {
  final String chamaId;
  const ChamaDetailScreen({super.key, required this.chamaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chamaAsync = ref.watch(
      FutureProvider.autoDispose((ref) =>
          ref.read(chamaRepositoryProvider).getChama(chamaId)).future,
    );

    return FutureBuilder<ChamaModel>(
      future: chamaAsync,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        if (snap.hasError || !snap.hasData) {
          return _ErrorScreen(onBack: () => context.pop());
        }
        return _ChamaDetailBody(chama: snap.data!, chamaId: chamaId);
      },
    );
  }
}

class _ChamaDetailBody extends ConsumerWidget {
  final ChamaModel chama;
  final String chamaId;

  const _ChamaDetailBody({
    required this.chama,
    required this.chamaId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(chamaProjectsProvider(chamaId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = currentUser?.id == chama.ownerId;
    final avatarColor =
        Color(int.parse(chama.avatarColor.replaceFirst('#', '0xFF')));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () =>
            ref.read(chamaProjectsProvider(chamaId).notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── App bar ────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 180,
              pinned: true,
              backgroundColor: avatarColor,
              leading: IconButton(
                icon: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 18),
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                if (isOwner) ...[
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined,
                        color: Colors.white),
                    tooltip: 'Invite code',
                    onPressed: () => _showInviteCode(context, chama),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white),
                    onPressed: () =>
                        context.push('/chamas/$chamaId/settings'),
                  ),
                ],
                const SizedBox(width: 4),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: avatarColor,
                  child: Stack(
                    children: [
                      // Decorative circle
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 48, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                chama.name,
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _InfoPill(
                                    icon: Icons.people_outline,
                                    label:
                                        '${chama.memberCount} members',
                                  ),
                                  const SizedBox(width: 8),
                                  _InfoPill(
                                    icon: Icons.folder_outlined,
                                    label:
                                        '${chama.activeProjectCount} active',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Projects header ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Projects',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.forest),
                    ),
                    const Spacer(),
                    if (isOwner)
                      TextButton.icon(
                        onPressed: () => context.push(
                          '/chamas/$chamaId/projects/create',
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('New'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.forest,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Projects list ──────────────────────────────────────────
            if (projectsState.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: AppColors.forest,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (projectsState.projects.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyProjects(
                  isOwner: isOwner,
                  onCreate: () => context.push(
                    '/chamas/$chamaId/projects/create',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ProjectCard(
                          project: projectsState.projects[i]),
                    ),
                    childCount: projectsState.projects.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showInviteCode(BuildContext context, ChamaModel chama) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Invite code',
                style:
                    AppTextStyles.h3.copyWith(color: AppColors.forest)),
            const SizedBox(height: 8),
            Text(
              'Share this code with people you want to invite',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.green),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.forest.withValues(alpha: 0.2)),
              ),
              child: Text(
                chama.inviteCode,
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.forest,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: chama.inviteCode));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Invite code copied'),
                    backgroundColor: AppColors.forest,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy code'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white)),
          ],
        ),
      );
}

class _EmptyProjects extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onCreate;
  const _EmptyProjects(
      {required this.isOwner, required this.onCreate});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_outlined,
                  color: AppColors.forest, size: 32),
            ),
            const SizedBox(height: 16),
            Text('No projects yet',
                style:
                    AppTextStyles.h4.copyWith(color: AppColors.forest)),
            const SizedBox(height: 8),
            Text(
              isOwner
                  ? 'Create the first project for this Chama'
                  : 'The Chama owner will create projects here',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.green),
              textAlign: TextAlign.center,
            ),
            if (isOwner) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create project'),
              ),
            ],
          ],
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(backgroundColor: AppColors.forest),
        body: const Center(
          child: CircularProgressIndicator(
              color: AppColors.forest, strokeWidth: 2),
        ),
      );
}

class _ErrorScreen extends StatelessWidget {
  final VoidCallback onBack;
  const _ErrorScreen({required this.onBack});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.cream),
            onPressed: onBack,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.sand, size: 48),
              const SizedBox(height: 16),
              Text('Could not load Chama',
                  style:
                      AppTextStyles.h4.copyWith(color: AppColors.forest)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: onBack, child: const Text('Go back')),
            ],
          ),
        ),
      );
}