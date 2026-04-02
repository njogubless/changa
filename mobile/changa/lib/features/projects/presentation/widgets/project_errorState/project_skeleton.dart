import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

// ── Fix: use ListView instead of Column inside SliverFillRemaining
// Column overflows because it tries to lay out all children at once
// without knowing the available height constraint.
class ProjectsLoadingSkeleton extends StatelessWidget {
  const ProjectsLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _SkeletonCard(),
          ),
          childCount: 3,
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: AppColors.sand.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.sand.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmer(18, double.infinity),
                    const SizedBox(height: 8),
                    _shimmer(12, 200),
                    const SizedBox(height: 16),
                    _shimmer(8, double.infinity),
                    const SizedBox(height: 12),
                    Row(children: [
                      _shimmer(28, 80),
                      const SizedBox(width: 16),
                      _shimmer(28, 80),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmer(double h, double w) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: AppColors.sand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}