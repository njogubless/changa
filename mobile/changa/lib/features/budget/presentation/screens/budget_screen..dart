import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class BudgetPlaceholderScreen extends StatelessWidget {
  const BudgetPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            snap: true,
            backgroundColor: AppColors.forest,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.forest,
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Budget',
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
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bar_chart_outlined,
                        color: AppColors.gold,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Budget planner',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.forest),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan your events, track spending,\nand manage personal budgets.\nComing soon.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.green, height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}