import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/payments/presentation/providers/payments_provider.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class ProfileStatsRow extends ConsumerWidget {
  final String userId;
  const ProfileStatsRow({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsState = ref.watch(projectsNotifierProvider);
    final contributionsAsync = ref.watch(myContributionsProvider);

    final myProjectCount =
        projectsState.projects.where((p) => p.ownerId == userId).length;

    final (contribCount, totalContributed) =
        contributionsAsync.when(
      data: (list) {
        final successful =
            list.where((c) => c.status.name == 'success').toList();
        final total =
            successful.fold(0.0, (sum, c) => sum + c.amount);
        return (successful.length, total);
      },
      loading: () => (0, 0.0),
      error: (_, __) => (0, 0.0),
    );

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
          _StatItem(value: '$myProjectCount', label: 'Projects\ncreated'),
          _Divider(),
          _StatItem(value: '$contribCount', label: 'Contributions\nmade'),
          _Divider(),
          _StatItem(
            value: CurrencyFormatter.formatCompact(totalContributed),
            label: 'Total\ncontributed',
          ),
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
            style: AppTextStyles.caption.copyWith(
              color: AppColors.green,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        width: 1,
        color: AppColors.sand.withValues(alpha: 0.5),
      );
}
