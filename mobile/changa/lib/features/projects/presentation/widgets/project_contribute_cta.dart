import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProjectContributeCTA extends StatelessWidget {
  final VoidCallback onContribute;
  const ProjectContributeCTA({super.key, required this.onContribute});

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
          onContribute();
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