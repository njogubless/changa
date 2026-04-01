import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:flutter/material.dart';

class ProjectSummaryCard extends StatelessWidget {
  final ProjectModel project;
  const ProjectSummaryCard({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgAll,
        border:
            Border.all(color: AppColors.forest.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Initial avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: AppRadius.mdAll,
            ),
            child: Center(
              child: Text(
                project.title[0].toUpperCase(),
                style: AppTextStyles.h3.copyWith(color: AppColors.cream),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: AppTextStyles.h4.copyWith(color: AppColors.forest),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${CurrencyFormatter.formatPercent(project.percentageFunded)} funded'
                  ' · ${CurrencyFormatter.format(project.deficit)} remaining',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
