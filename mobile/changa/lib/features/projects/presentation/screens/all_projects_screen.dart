import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Aggregates projects from all chamas the user belongs to
final allChamaProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final chamaState = ref.watch(chamaListProvider);
  final projects = <ProjectModel>[];

  for (final chama in chamaState.chamas) {
    final chamaProjects = ref.watch(chamaProjectsProvider(chama.id));
    projects.addAll(chamaProjects.projects);
  }

  // Sort by most recently created
  projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return projects;
});

final allProjectsLoadingProvider = Provider<bool>((ref) {
  final chamaState = ref.watch(chamaListProvider);
  if (chamaState.isLoading) return true;
  for (final chama in chamaState.chamas) {
    if (ref.watch(chamaProjectsProvider(chama.id)).isLoading) return true;
  }
  return false;
});

class AllProjectsScreen extends ConsumerWidget {
  const AllProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(allChamaProjectsProvider);
    final isLoading = ref.watch(allProjectsLoadingProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () async {
          ref.read(chamaListProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
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

            // ── Count bar ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Text(
                  isLoading
                      ? 'Loading...'
                      : '${projects.length} project${projects.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.green),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────
            if (isLoading)
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
            else if (projects.isEmpty)
              SliverFillRemaining(child: _EmptyProjects())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ProjectCard(project: projects[i]),
                    ),
                    childCount: projects.length,
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