import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectContributorsSection extends ConsumerWidget {
  final String projectId;
  const ProjectContributorsSection({super.key, required this.projectId});

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
            _ContributorsHeader(count: contributors.length),
            const SizedBox(height: 12),
            ...contributors.take(5).map((c) => _ContributorRow(contributor: c)),
            if (contributors.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${contributors.length - 5} more contributors',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.sage),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContributorsHeader extends StatelessWidget {
  final int count;
  const _ContributorsHeader({required this.count});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('Contributors',
              style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.sage.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

class _ContributorRow extends StatelessWidget {
  final dynamic contributor;
  const _ContributorRow({required this.contributor});

  String get _initials {
    final name = (contributor.fullName ?? 'A') as String;
    return name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.sage.withValues(alpha: 0.15),
              child: Text(
                _initials,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                contributor.fullName ?? 'Anonymous',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.forest),
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