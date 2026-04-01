import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProjectSectionLabel extends StatelessWidget {
  final String text;
  const ProjectSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTextStyles.label.copyWith(
      color: AppColors.forest,
      letterSpacing: 0.8,
    ),
  );
}

class ProjectErrorBanner extends StatelessWidget {
  final String message;
  const ProjectErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}

class ProjectVisibilityOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const ProjectVisibilityOption({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.forest.withValues(alpha: 0.08)
                  : Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.forest : AppColors.sand,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.h4.copyWith(
                color: selected ? AppColors.forest : AppColors.green,
              ),
            ),
            Text(
              subtitle,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.green.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProjectToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ProjectToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: AppColors.sand),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.green.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.forest,
        ),
      ],
    ),
  );
}


class ProjectDeadlinePicker extends StatelessWidget {
  final DateTime? deadline;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const ProjectDeadlinePicker({
    super.key,
    required this.deadline,
    required this.onTap,
    required this.onClear,
  });

  String _formatDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: deadline != null ? AppColors.forest : AppColors.sand,
          ),
          const SizedBox(width: 10),
          Text(
            deadline != null ? _formatDate(deadline!) : 'No deadline',
            style: AppTextStyles.bodyMedium.copyWith(
              color: deadline != null ? AppColors.forest : Colors.grey.shade400,
            ),
          ),
          const Spacer(),
          if (deadline != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 16, color: AppColors.sand),
            ),
        ],
      ),
    ),
  );
}

class ProjectDangerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ProjectDangerAction({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: color.withValues(alpha: 0.5),
            size: 18,
          ),
        ],
      ),
    ),
  );
}


Future<DateTime?> pickProjectDeadline(
  BuildContext context, {
  DateTime? initial,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial ?? DateTime.now().add(const Duration(days: 30)),
    firstDate: DateTime.now().add(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    builder:
        (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.forest,
              onPrimary: AppColors.cream,
            ),
          ),
          child: child!,
        ),
  );
}
