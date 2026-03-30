import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

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
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.forest,
                leading: IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  if (isOwner)
                    IconButton(
                      icon: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.edit_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () {},
                    ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background:
                      project.coverImageUrl != null
                          ? Image.network(
                            project.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) =>
                                    _HeroPlaceholder(title: project.title),
                          )
                          : _HeroPlaceholder(title: project.title),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              project.title,
                              style: AppTextStyles.h1.copyWith(
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: project.status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (project.visibility == ProjectVisibility.private)
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Private project',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: AppRadius.lgAll,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total raised',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.mint,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              CurrencyFormatter.format(project.raisedAmount),
                              style: AppTextStyles.amount.copyWith(
                                color: AppColors.cream,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FundingProgressBar(
                              percentage: project.percentageFunded,
                              isFunded: project.isFunded,
                              height: 10,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _AmountChip(
                                  label: 'Goal',
                                  value: CurrencyFormatter.format(
                                    project.targetAmount,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _AmountChip(
                                  label: 'Remaining',
                                  value: CurrencyFormatter.format(
                                    project.deficit,
                                  ),
                                ),
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${project.contributorCount}',
                                      style: AppTextStyles.h3.copyWith(
                                        color: AppColors.gold,
                                      ),
                                    ),
                                    Text(
                                      'contributors',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.mint,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (project.description != null) ...[
                        Text(
                          'About this project',
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

                      _ContributorsSection(projectId: projectId),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          bottomNavigationBar:
              project.status == ProjectStatus.active
                  ? _ContributeCTA(projectId: projectId)
                  : null,
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
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

class _AmountChip extends StatelessWidget {
  final String label;
  final String value;
  const _AmountChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.cream,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.mint),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Row(
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
}

class _ContributorsSection extends ConsumerWidget {
  final String projectId;
  const _ContributorsSection({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectContributorsProvider(projectId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (contributors) {
        if (contributors.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Contributors',
                  style: AppTextStyles.h4.copyWith(color: AppColors.forest),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${contributors.length}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...contributors.take(5).map((c) => _ContributorRow(contributor: c)),
            if (contributors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${contributors.length - 5} more contributors',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.sage,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContributorRow extends StatelessWidget {
  final dynamic contributor;
  const _ContributorRow({required this.contributor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.forest,
            radius: 40,
            child: Text(
              contributor.fullName.split(' ').map((e) => e[0]).take(2).join(),
              style: TextStyle(
                color: AppColors.cream,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            // radius: 18,
            // backgroundColor: AppColors.sage.withValues(alpha: 0.15),
            // child: Text(
            //   (contributor.fullName ?? 'A')[0].toUpperCase(),
            //   style: AppTextStyles.bodySmall.copyWith(
            //     color: AppColors.forest,
            //     fontWeight: FontWeight.w700,
            //   ),
            // ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contributor.fullName ?? 'Anonymous',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest),
            ),
          ),
          Text(
            CurrencyFormatter.format(contributor.total as double),
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(contributor.percentage as double).toStringAsFixed(1)}%',
            style: AppTextStyles.caption.copyWith(color: AppColors.sage),
          ),
        ],
      ),
    );
  }
}



class _ContributeCTA extends StatelessWidget {
  final String projectId;
  const _ContributeCTA({required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          top: BorderSide(color: AppColors.sand.withValues(alpha: 0.5)),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.paymentPath(projectId));
        },
        icon: const Icon(Icons.favorite_outline, size: 18),
        label: const Text('Contribute now'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: AppColors.cream,
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final String title;
  const _HeroPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forest,
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'C',
          style: AppTextStyles.display1.copyWith(
            color: AppColors.cream.withValues(alpha: 0.2),
            fontSize: 80,
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(backgroundColor: AppColors.forest),
      body: const Center(
        child: CircularProgressIndicator(
          color: AppColors.forest,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  final VoidCallback onBack;
  const _DetailError({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
}
