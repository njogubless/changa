import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:changa/features/projects/presentation/widgets/project_errorState/project_skeleton.dart';
import 'package:changa/features/projects/presentation/widgets/project_list/project_app_bar.dart';
import 'package:changa/features/projects/presentation/widgets/project_list/project_search_bar.dart';
import 'package:changa/features/projects/presentation/widgets/project_list/projects_states.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends ConsumerState<ProjectsListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(projectsNotifierProvider.notifier).loadMore();
    }
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) {
      _searchCtrl.clear();
      ref.read(projectsNotifierProvider.notifier).load();
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _showSearch = false);
    ref.read(projectsNotifierProvider.notifier).load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(projectsNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final firstName = user?.fullName.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => ref.read(projectsNotifierProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            ProjectsAppBar(
              firstName: firstName,
              showSearch: _showSearch,
              onToggleSearch: _toggleSearch,
            ),

            if (_showSearch)
              ProjectsSearchBar(
                controller: _searchCtrl,
                onChanged: (q) {
                  if (q.length >= 2 || q.isEmpty) {
                    ref.read(projectsNotifierProvider.notifier).load(
                          search: q.isEmpty ? null : q,
                        );
                  }
                },
              ),

            ProjectsCountBar(
              count: state.projects.length,
              isLoading: state.isLoading,
              hasSearch: state.searchQuery.isNotEmpty,
              onClearSearch: _clearSearch,
            ),

            // Content states
            if (state.isLoading)
              const ProjectsLoadingSkeleton() 
            else if (state.error != null)
              SliverFillRemaining(
                child: ProjectsErrorState(
                  onRetry: () =>
                      ref.read(projectsNotifierProvider.notifier).refresh(),
                ),
              )
            else if (state.projects.isEmpty)
              SliverFillRemaining(
                child: ProjectsEmptyState(
                  message: 'No projects found.\nStart the first harambee!',
                  onAction: () => context.push(AppRoutes.createProject),
                  actionLabel: 'Create project',
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.forest,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}