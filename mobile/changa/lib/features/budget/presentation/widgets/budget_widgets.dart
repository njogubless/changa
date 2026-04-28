import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';



final _fmt = NumberFormat('#,##0', 'en_KE');
String kesFormat(double v) => 'KES ${_fmt.format(v)}';



class BudgetStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const BudgetStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.green),
            ),
          ],
        ),
      );
}



class BudgetSectionLabel extends StatelessWidget {
  final String text;
  const BudgetSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: AppColors.forest,
          letterSpacing: 0.8,
        ),
      );
}



class BudgetEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final String? buttonLabel;
  final VoidCallback? onButton;

  const BudgetEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.buttonLabel,
    this.onButton,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.green, height: 1.6),
                textAlign: TextAlign.center,
              ),
              if (buttonLabel != null && onButton != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: onButton,
                    child: Text(buttonLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}



class BudgetErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const BudgetErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.sand, size: 48),
            const SizedBox(height: 16),
            Text(message,
                style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
}



class BudgetErrorBanner extends StatelessWidget {
  final String message;
  const BudgetErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
}





List<BudgetCategory> categoriesFor(BudgetType type) {
  switch (type) {
    case BudgetType.personal:
      return [
        BudgetCategory.food,
        BudgetCategory.transport,
        BudgetCategory.rent,
        BudgetCategory.utilities,
        BudgetCategory.healthcare,
        BudgetCategory.education,
        BudgetCategory.entertainment,
        BudgetCategory.clothing,
        BudgetCategory.savings,
        BudgetCategory.other,
      ];
    case BudgetType.event:
      return [
        BudgetCategory.venue,
        BudgetCategory.catering,
        BudgetCategory.decoration,
        BudgetCategory.photography,
        BudgetCategory.music,
        BudgetCategory.transport_event,
        BudgetCategory.gifts,
        BudgetCategory.other,
      ];
    case BudgetType.chamaContribution:
      return [
        BudgetCategory.contribution,
        BudgetCategory.other,
      ];
  }
}