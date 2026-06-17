import 'package:changa/core/errors/failures.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
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
  }) =>
      ProjectsState(
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
      final result = await _repo.getProjects(
        page: 1,
        search: search,
      );
      state = state.copyWith(
        projects: result.items,
        isLoading: false,
        currentPage: 1,
        totalPages: result.pages,
      );
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: failureMessage(e));
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

  Future<void> refresh() => load(search: state.searchQuery.isNotEmpty ? state.searchQuery : null);
}

final projectsNotifierProvider =
    StateNotifierProvider.autoDispose<ProjectsNotifier, ProjectsState>(
  (ref) => ProjectsNotifier(ref.watch(projectsRepositoryProvider)),
);



class AllProjectsState {
  final List<ProjectModel> projects;
  final bool isLoading;
  final String? error;

  const AllProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  AllProjectsState copyWith({
    List<ProjectModel>? projects,
    bool? isLoading,
    String? error,
  }) =>
      AllProjectsState(
        projects: projects ?? this.projects,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AllProjectsNotifier extends StateNotifier<AllProjectsState> {
  final ProjectsRepository _repo;

  AllProjectsNotifier(this._repo) : super(const AllProjectsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.getMyProjects();
      state = AllProjectsState(projects: result.items);
    } on Failure catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: failureMessage(e));
    }
  }

  Future<void> refresh() => load();
}

final allProjectsNotifierProvider =
    StateNotifierProvider.autoDispose<AllProjectsNotifier, AllProjectsState>(
  (ref) {
    final notifier = AllProjectsNotifier(ref.watch(projectsRepositoryProvider));
    notifier.load();
    return notifier;
  },
);



final projectDetailProvider =
    FutureProvider.autoDispose.family<ProjectModel, String>((ref, id) async {
  return ref.read(projectsRepositoryProvider).getProject(id);
});

final projectContributorsProvider =
    FutureProvider.autoDispose.family<List<ContributorModel>, String>(
        (ref, id) async {
  return ref.read(projectsRepositoryProvider).getContributors(id);
});



class CreateProjectState {
  final bool isLoading;
  final String? error;
  final ProjectModel? created;

  const CreateProjectState({
    this.isLoading = false,
    this.error,
    this.created,
  });
}

class CreateProjectNotifier extends StateNotifier<CreateProjectState> {
  final ProjectsRepository _repo;

  CreateProjectNotifier(this._repo) : super(const CreateProjectState());

  Future<void> create({
    required String title,
    String? description,
    required double targetAmount,
    required String visibility,
    required bool isAnonymous,
    DateTime? deadline,
  }) async {
    state = const CreateProjectState(isLoading: true);
    try {
      final project = await _repo.createProject(
        title: title,
        description: description,
        targetAmount: targetAmount,
        visibility: visibility,
        isAnonymous: isAnonymous,
        deadline: deadline,
      );
      state = CreateProjectState(created: project);
    } catch (e) {
      state = CreateProjectState(error: e.toString());
    }
  }

  void reset() => state = const CreateProjectState();
}

final createProjectProvider =
    StateNotifierProvider<CreateProjectNotifier, CreateProjectState>(
  (ref) => CreateProjectNotifier(ref.watch(projectsRepositoryProvider)),
);
