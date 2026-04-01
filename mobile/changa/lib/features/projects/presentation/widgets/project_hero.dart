import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

class ProjectHero extends StatelessWidget {
  final String title;
  final String? coverImageUrl;
  final bool isOwner;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const ProjectHero({
    super.key,
    required this.title,
    this.coverImageUrl,
    required this.isOwner,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.forest,
      leading: IconButton(
        icon: _CircleIcon(icon: Icons.arrow_back),
        onPressed: onBack,
      ),
      actions: [
        if (isOwner)
          IconButton(
            icon: _CircleIcon(icon: Icons.edit_outlined),
            onPressed: onEdit,
          ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: coverImageUrl != null
            ? Image.network(
                coverImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _HeroPlaceholder(title: title),
              )
            : _HeroPlaceholder(title: title),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  const _CircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

class _HeroPlaceholder extends StatelessWidget {
  final String title;
  const _HeroPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.forest,
        child: Center(
          child: Text(
            title.isNotEmpty ? title[0].toUpperCase() : 'C',
            style: AppTextStyles.display1.copyWith(
              color: AppColors.cream.withValues(alpha: 0.2),
              fontSize: 80,
            ),
          ),
        ),
      );
}