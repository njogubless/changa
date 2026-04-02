import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectsAppBar extends StatelessWidget {
  final String firstName;
  final bool showSearch;
  final VoidCallback onToggleSearch;

  const ProjectsAppBar({
    super.key,
    required this.firstName,
    required this.showSearch,
    required this.onToggleSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 130,
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: AppColors.forest,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: Icon(
            showSearch ? Icons.close : Icons.search,
            color: AppColors.cream,
          ),
          onPressed: onToggleSearch,
        ),
        IconButton(
          icon: const Icon(Icons.add, color: AppColors.cream),
          onPressed: () => context.push(AppRoutes.createProject),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: AppColors.forest,
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                firstName.isNotEmpty ? 'Habari, $firstName 👋' : 'Habari 👋',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.mint),
              ),
              const SizedBox(height: 4),
              Text(
                'What are we\ncontributing to?',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.cream,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}