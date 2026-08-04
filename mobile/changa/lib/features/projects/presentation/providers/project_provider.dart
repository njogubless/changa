import 'package:changa/core/errors/failures.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/data/repositories/project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ProjectsRepository(ref.watch(apiClientProvider)),
);

class ProjectsState {
  final List<ProjectModel> projects;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final int totalPages;
  final String searchQuery;

  const ProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.totalPages = 1,
    this.searchQuery = '',
  });

  bool get hasMore => currentPage < totalPages;

  ProjectsState copyWith({
    List<ProjectModel>? projects,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    int? totalPages,
    String? searchQuery,
  }) => ProjectsState(
    projects: projects ?? this.projects,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: error,
    currentPage: currentPage ?? this.currentPage,
    totalPages: totalPages ?? this.totalPages,
    searchQuery: searchQuery ?? this.searchQuery,
  );
}

class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final ProjectsRepository _repo;

  ProjectsNotifier(this._repo) : super(const ProjectsState());

  Future<void> load({String? search}) async {
    state = state.copyWith(isLoading: true, searchQuery: search ?? '');
    try {
      final result = await _repo.getProjects(page: 1, search: search);
      state = state.copyWith(
        projects: result.items,
        isLoading: false,
        currentPage: 1,
        totalPages: result.pages,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getProjects(
        page: state.currentPage + 1,
        search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      );
      state = state.copyWith(
        projects: [...state.projects, ...result.items],
        isLoadingMore: false,
        currentPage: result.page,
        totalPages: result.pages,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() =>
      load(search: state.searchQuery.isNotEmpty ? state.searchQuery : null);
}

final projectsNotifierProvider =
    StateNotifierProvider<ProjectsNotifier, ProjectsState>(
      (ref) => ProjectsNotifier(ref.watch(projectsRepositoryProvider)),
    );

final projectDetailProvider = FutureProvider.family<ProjectModel, String>((
  ref,
  id,
) async {
  return ref.watch(projectsRepositoryProvider).getProject(id);
});

final projectContributorsProvider =
    FutureProvider.family<List<ContributorModel>, String>((ref, id) async {
      return ref.watch(projectsRepositoryProvider).getContributors(id);
    });

// createProjectProvider (bare POST /projects) was removed here — that
// route never existed server-side and this provider had zero callers;
// the real, working creation flow is createChamaProjectProvider in
// chama_provider.dart, which posts to /chamas/{chama_id}/projects. See
// API-01 in docs/Changa_Engineering_audit.md.

// ── All-projects aggregator ──────────────────────────────────────────────────
// Combines projects from every Chama the user belongs to into one sorted list.
// Uses ref.listen (not ref.watch in a loop) to avoid the variable-subscription
// anti-pattern.

class AllProjectsState {
  final List<ProjectModel> projects;
  final bool isLoading;
  final String? error;

  const AllProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });
}

class AllProjectsNotifier extends StateNotifier<AllProjectsState> {
  final Ref _ref;

  AllProjectsNotifier(this._ref)
    : super(const AllProjectsState(isLoading: true)) {
    // React to every chama list change (including initial load)
    _ref.listen(
      chamaListProvider,
      (_, chamaState) => _recompute(chamaState),
      fireImmediately: true,
    );
  }

  void _recompute(ChamaListState chamaState) {
    if (chamaState.isLoading && state.projects.isEmpty) {
      state = const AllProjectsState(isLoading: true);
      return;
    }
    final allProjects = <ProjectModel>[];
    for (final chama in chamaState.chamas) {
      // read (not watch) is safe here — we're inside a listener callback
      final cp = _ref.read(chamaProjectsProvider(chama.id));
      allProjects.addAll(cp.projects);
    }
    allProjects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = AllProjectsState(
      projects: allProjects,
      isLoading: chamaState.isLoading,
    );
  }

  Future<void> refresh() async {
    state = AllProjectsState(isLoading: true, projects: state.projects);
    _ref.read(chamaListProvider.notifier).refresh();
  }
}

final allProjectsNotifierProvider =
    StateNotifierProvider<AllProjectsNotifier, AllProjectsState>(
      (ref) => AllProjectsNotifier(ref),
    );
