import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AllProjectsScreen extends ConsumerWidget {
  const AllProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(allProjectsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => ref.read(allProjectsNotifierProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              floating: true,
              snap: true,
              pinned: false,
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
                        'Projects',
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Text(
                  state.isLoading
                      ? 'Loading...'
                      : '${state.projects.length} project${state.projects.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.green),
                ),
              ),
            ),
            if (state.isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(
                      color: AppColors.forest,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              )
            else if (state.projects.isEmpty)
              SliverFillRemaining(child: _EmptyProjects())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ProjectCard(project: state.projects[i]),
                    ),
                    childCount: state.projects.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
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
                  color: AppColors.sage.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_outlined,
                    color: AppColors.forest, size: 32),
              ),
              const SizedBox(height: 16),
              Text('No projects yet',
                  style:
                      AppTextStyles.h4.copyWith(color: AppColors.forest)),
              const SizedBox(height: 8),
              Text(
                'Join or create a Chama, then\nthe owner can add projects.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.green),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
