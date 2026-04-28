import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';
import 'package:changa/features/chama/data/repository/chama_repository.dart';

import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



final chamaRepositoryProvider = Provider<ChamaRepository>(
  (ref) => ChamaRepository(ref.watch(apiClientProvider)),
);



class ChamaListState {
  final List<ChamaModel> chamas;
  final bool isLoading;
  final String? error;

  const ChamaListState({
    this.chamas = const [],
    this.isLoading = false,
    this.error,
  });

  ChamaListState copyWith({
    List<ChamaModel>? chamas,
    bool? isLoading,
    String? error,
  }) =>
      ChamaListState(
        chamas: chamas ?? this.chamas,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ChamaListNotifier extends StateNotifier<ChamaListState> {
  final ChamaRepository _repo;

  ChamaListNotifier(this._repo) : super(const ChamaListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.getMyChamas();
      state = state.copyWith(chamas: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  void addChama(ChamaModel chama) {
    state = state.copyWith(chamas: [chama, ...state.chamas]);
  }
}

final chamaListProvider =
    StateNotifierProvider<ChamaListNotifier, ChamaListState>(
  (ref) => ChamaListNotifier(ref.watch(chamaRepositoryProvider)),
);



class CreateChamaState {
  final bool isLoading;
  final String? error;
  final ChamaModel? created;

  const CreateChamaState({
    this.isLoading = false,
    this.error,
    this.created,
  });
}

class CreateChamaNotifier extends StateNotifier<CreateChamaState> {
  final ChamaRepository _repo;

  CreateChamaNotifier(this._repo) : super(const CreateChamaState());

  Future<void> create({
    required String name,
    String? description,
    String avatarColor = '#1B4332',
  }) async {
    state = const CreateChamaState(isLoading: true);
    try {
      final chama = await _repo.createChama(
        name: name,
        description: description,
        avatarColor: avatarColor,
      );
      state = CreateChamaState(created: chama);
    } catch (e) {
      state = CreateChamaState(error: e.toString());
    }
  }

  void reset() => state = const CreateChamaState();
}

final createChamaProvider =
    StateNotifierProvider<CreateChamaNotifier, CreateChamaState>(
  (ref) => CreateChamaNotifier(ref.watch(chamaRepositoryProvider)),
);



class JoinChamaState {
  final bool isLoading;
  final String? error;
  final ChamaModel? joined;

  const JoinChamaState({
    this.isLoading = false,
    this.error,
    this.joined,
  });
}

class JoinChamaNotifier extends StateNotifier<JoinChamaState> {
  final ChamaRepository _repo;

  JoinChamaNotifier(this._repo) : super(const JoinChamaState());

  Future<void> join(String inviteCode) async {
    state = const JoinChamaState(isLoading: true);
    try {
      final chama = await _repo.joinChama(inviteCode);
      state = JoinChamaState(joined: chama);
    } catch (e) {
      state = JoinChamaState(error: _friendlyError(e.toString()));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('404') || raw.contains('Invalid invite')) {
      return 'Invalid invite code. Please check and try again.';
    }
    if (raw.contains('400') || raw.contains('already a member')) {
      return 'You are already a member of this Chama.';
    }
    if (raw.contains('Network') || raw.contains('connection')) {
      return 'No internet connection.';
    }
    return 'Could not join Chama. Please try again.';
  }

  void reset() => state = const JoinChamaState();
}

final joinChamaProvider =
    StateNotifierProvider<JoinChamaNotifier, JoinChamaState>(
  (ref) => JoinChamaNotifier(ref.watch(chamaRepositoryProvider)),
);



class ChamaProjectsState {
  final List<ProjectModel> projects;
  final bool isLoading;
  final String? error;

  const ChamaProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ChamaProjectsState copyWith({
    List<ProjectModel>? projects,
    bool? isLoading,
    String? error,
  }) =>
      ChamaProjectsState(
        projects: projects ?? this.projects,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ChamaProjectsNotifier extends StateNotifier<ChamaProjectsState> {
  final ChamaRepository _repo;
  final String chamaId;

  ChamaProjectsNotifier(this._repo, this.chamaId)
      : super(const ChamaProjectsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.getChamaProjects(chamaId);
      state = state.copyWith(projects: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();
}

final chamaProjectsProvider = StateNotifierProvider.family<
    ChamaProjectsNotifier, ChamaProjectsState, String>(
  (ref, chamaId) =>
      ChamaProjectsNotifier(ref.watch(chamaRepositoryProvider), chamaId),
);



class CreateChamaProjectState {
  final bool isLoading;
  final String? error;
  final ProjectModel? created;

  const CreateChamaProjectState({
    this.isLoading = false,
    this.error,
    this.created,
  });
}

class CreateChamaProjectNotifier
    extends StateNotifier<CreateChamaProjectState> {
  final ChamaRepository _repo;

  CreateChamaProjectNotifier(this._repo)
      : super(const CreateChamaProjectState());

  Future<void> create({
    required String chamaId,
    required String title,
    String? description,
    required double targetAmount,
    required String paymentType,
    required String paymentNumber,
    String? paymentName,
    String? accountReference,
    bool isAnonymous = false,
    DateTime? deadline,
  }) async {
    state = const CreateChamaProjectState(isLoading: true);
    try {
      final project = await _repo.createChamaProject(
        chamaId: chamaId,
        title: title,
        description: description,
        targetAmount: targetAmount,
        paymentType: paymentType,
        paymentNumber: paymentNumber,
        paymentName: paymentName,
        accountReference: accountReference,
        isAnonymous: isAnonymous,
        deadline: deadline,
      );
      state = CreateChamaProjectState(created: project);
    } catch (e) {
      state = CreateChamaProjectState(error: e.toString());
    }
  }

  void reset() => state = const CreateChamaProjectState();
}

final createChamaProjectProvider = StateNotifierProvider<
    CreateChamaProjectNotifier, CreateChamaProjectState>(
  (ref) => CreateChamaProjectNotifier(ref.watch(chamaRepositoryProvider)),
);