import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:changa/features/projects/presentation/widgets/project_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


class ProjectsListScreen extends ConsumerStatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  ConsumerState<ProjectsListScreen> createState() =>
      _ProjectsListScreenState();
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
      
            SliverAppBar(
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
                    _showSearch ? Icons.close : Icons.search,
                    color: AppColors.cream,
                  ),
                  onPressed: () {
                    setState(() => _showSearch = !_showSearch);
                    if (!_showSearch) {
                      _searchCtrl.clear();
                      ref.read(projectsNotifierProvider.notifier).load();
                    }
                  },
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
                        firstName.isNotEmpty
                            ? 'Habari, $firstName 👋'
                            : 'Habari 👋',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.mint,
                        ),
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
            ),

         
            if (_showSearch)
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.forest,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: 'Search projects...',
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: AppColors.green),
                      fillColor: AppColors.cream,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pillAll,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillAll,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillAll,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (q) {
                      if (q.length >= 2 || q.isEmpty) {
                        ref.read(projectsNotifierProvider.notifier).load(
                              search: q.isEmpty ? null : q,
                            );
                      }
                    },
                  ),
                ),
              ),

           
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Text(
                      state.isLoading
                          ? 'Loading...'
                          : '${state.projects.length} project${state.projects.length == 1 ? '' : 's'}',
                      style:
                          AppTextStyles.bodySmall.copyWith(color: AppColors.green),
                    ),
                    const Spacer(),
                    if (state.searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _showSearch = false);
                          ref.read(projectsNotifierProvider.notifier).load();
                        },
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
            ),

            
            if (state.isLoading)
              const SliverFillRemaining(child: _LoadingSkeleton())
            else if (state.error != null)
              SliverFillRemaining(
                child: _ErrorState(
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



class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SkeletonCard(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
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
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
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
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: AppColors.sand.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
      );
}



class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

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
            Text(
              'Could not load projects',
              style: AppTextStyles.h4.copyWith(color: AppColors.forest),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.green),
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
