import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:changa/features/projects/presentation/widgets/project_contribute_cta.dart';
import 'package:changa/features/projects/presentation/widgets/project_contributors.dart';
import 'package:changa/features/projects/presentation/widgets/project_hero.dart';
import 'package:changa/features/projects/presentation/widgets/project_stats_card.dart';

import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final currentUser = ref.watch(currentUserProvider);

    return projectAsync.when(
      loading: () => const _DetailSkeleton(),
      error: (e, _) => _DetailError(onBack: () => context.pop()),
      data: (project) {
        final isOwner = currentUser?.id == project.ownerId;
        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              ProjectHero(
                title: project.title,
                coverImageUrl: project.coverImageUrl,
                isOwner: isOwner,
                onBack: () => context.pop(),
                onEdit:
                    () => context.push(
                      '/projects/${project.id}/edit',
                      extra: project,
                    ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProjectHeader(project: project),
                      const SizedBox(height: 24),
                      ProjectStatsCard(project: project),
                      const SizedBox(height: 24),
                      if (project.description != null) ...[
                        Text(
                          '',
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          project.description!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.green,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (project.deadline != null) ...[
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Deadline',
                          value: _formatDate(project.deadline!),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ProjectContributorsSection(projectId: projectId),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar:
              project.status == ProjectStatus.active
                  ? ProjectContributeCTA(
                    onContribute:
                        () => context.push(AppRoutes.paymentPath(projectId)),
                  )
                  : null,
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _ProjectHeader extends StatelessWidget {
  final ProjectModel project;
  const _ProjectHeader({required this.project});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              project.title,
              style: AppTextStyles.h1.copyWith(color: AppColors.forest),
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: project.status),
        ],
      ),
      // if (project.visibility == ProjectVisibility.private) ...[
      //   const SizedBox(height: 6),
      //   Row(
      //     children: [
      //       const Icon(Icons.lock_outline,
      //           size: 14, color: AppColors.gold),
      //       const SizedBox(width: 4),
      //       Text('Private project',
      //           style: AppTextStyles.caption
      //               .copyWith(color: AppColors.gold)),
      //     ],
      //   ),
      // ],
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.sage),
      const SizedBox(width: 8),
      Text(
        '$label: ',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
      ),
      Text(
        value,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.forest,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.cream,
    appBar: AppBar(backgroundColor: AppColors.forest),
    body: const Center(
      child: CircularProgressIndicator(color: AppColors.forest, strokeWidth: 2),
    ),
  );
}

class _DetailError extends StatelessWidget {
  final VoidCallback onBack;
  const _DetailError({required this.onBack});

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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.sand, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load project',
              style: AppTextStyles.h4.copyWith(color: AppColors.forest),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    ),
  );
}
