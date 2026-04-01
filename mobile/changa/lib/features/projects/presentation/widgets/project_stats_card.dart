import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';

class ProjectStatsCard extends StatelessWidget {
  final ProjectModel project;
  const ProjectStatsCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: AppTextStyles.amount.copyWith(color: AppColors.cream),
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
                value: CurrencyFormatter.format(project.targetAmount),
              ),
              const SizedBox(width: 12),
              _AmountChip(
                label: 'Remaining',
                value: CurrencyFormatter.format(project.deficit),
              ),
              const Spacer(),
              _ContributorCount(count: project.contributorCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final String value;
  const _AmountChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.cream, fontWeight: FontWeight.w700)),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: AppColors.mint)),
        ],
      );
}

class _ContributorCount extends StatelessWidget {
  final int count;
  const _ContributorCount({required this.count});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$count',
              style: AppTextStyles.h3.copyWith(color: AppColors.gold)),
          Text('contributors',
              style: AppTextStyles.caption.copyWith(color: AppColors.mint)),
        ],
      );
}