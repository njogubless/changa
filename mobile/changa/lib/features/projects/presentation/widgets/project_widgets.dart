import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';



class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  const ProjectCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.projectDetailPath(project.id)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.sand.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image or placeholder
            _CoverImage(url: project.coverImageUrl, title: project.title),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + visibility badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: AppTextStyles.h4.copyWith(
                            color: AppColors.forest,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // if (project.visibility == ProjectVisibility.private)
                      //   _Badge(label: 'Private', color: AppColors.gold),
                    ],
                  ),
                  if (project.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      project.description!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.green,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Progress bar
                  FundingProgressBar(
                    percentage: project.percentageFunded,
                    isFunded: project.isFunded,
                  ),
                  const SizedBox(height: 12),

                  // Stats row
                  Row(
                    children: [
                      _StatItem(
                        label: 'Raised',
                        value: CurrencyFormatter.formatCompact(
                            project.raisedAmount),
                        color: AppColors.forest,
                      ),
                      _divider(),
                      _StatItem(
                        label: 'Goal',
                        value: CurrencyFormatter.formatCompact(
                            project.targetAmount),
                        color: AppColors.green,
                      ),
                      _divider(),
                      _StatItem(
                        label: 'People',
                        value: project.contributorCount.toString(),
                        color: AppColors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: AppColors.sand,
      );
}



class _CoverImage extends StatelessWidget {
  final String? url;
  final String title;
  const _CoverImage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    if (url != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.network(
          url!,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    // Generate a consistent color from title
    final colors = [
      AppColors.forest,
      AppColors.green,
      AppColors.sage,
      AppColors.tera,
      AppColors.gold,
    ];
    final color = colors[title.length % colors.length];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 120,
        width: double.infinity,
        color: color.withValues(alpha: 0.15),
        child: Center(
          child: Text(
            title.isNotEmpty ? title[0].toUpperCase() : 'C',
            style: AppTextStyles.display1.copyWith(
              color: color.withValues(alpha: 0.4),
              fontSize: 56,
            ),
          ),
        ),
      ),
    );
  }
}



class FundingProgressBar extends StatelessWidget {
  final double percentage;
  final bool isFunded;
  final double height;

  const FundingProgressBar({
    super.key,
    required this.percentage,
    required this.isFunded,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = (percentage / 100).clamp(0.0, 1.0);
    final barColor = isFunded ? AppColors.success : AppColors.forest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: height,
            backgroundColor: AppColors.sand.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          isFunded
              ? 'Goal reached!'
              : '${CurrencyFormatter.formatPercent(percentage)} funded',
          style: AppTextStyles.caption.copyWith(
            color: isFunded ? AppColors.success : AppColors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}



class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTextStyles.h4.copyWith(color: color),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.green.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}


class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}



class StatusBadge extends StatelessWidget {
  final ProjectStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ProjectStatus.active    => ('Active', AppColors.success),
      ProjectStatus.completed => ('Completed', AppColors.info),
      ProjectStatus.paused    => ('Paused', AppColors.warning),
      ProjectStatus.cancelled => ('Cancelled', AppColors.error),
    };
    return _Badge(label: label, color: color);
  }
}



class ProjectsEmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const ProjectsEmptyState({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                color: AppColors.sage,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'Get started'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
