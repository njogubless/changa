import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

// ── Count bar ──────────────────────────────────────────────────────────────
class ProjectsCountBar extends StatelessWidget {
  final int count;
  final bool isLoading;
  final bool hasSearch;
  final VoidCallback onClearSearch;

  const ProjectsCountBar({
    super.key,
    required this.count,
    required this.isLoading,
    required this.hasSearch,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Text(
              isLoading
                  ? 'Loading...'
                  : '$count project${count == 1 ? '' : 's'}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
            ),
            const Spacer(),
            if (hasSearch)
              GestureDetector(
                onTap: onClearSearch,
                child: Text(
                  'Clear search',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.tera,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────
class ProjectsErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const ProjectsErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.sand.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_outlined,
                  color: AppColors.sand, size: 34),
            ),
            const SizedBox(height: 20),
            Text('Could not load projects',
                style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
}