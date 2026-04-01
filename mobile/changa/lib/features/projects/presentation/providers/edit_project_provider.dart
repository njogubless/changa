import 'package:changa/features/projects/data/repositories/project_repository.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


class EditProjectState {
  final bool isLoading;
  final String? error;
  final bool saved;

  const EditProjectState({
    this.isLoading = false,
    this.error,
    this.saved = false,
  });
}


class EditProjectNotifier extends StateNotifier<EditProjectState> {
  final ProjectsRepository _repo;
  EditProjectNotifier(this._repo) : super(const EditProjectState());

  Future<void> update({
    required String projectId,
    required String title,
    String? description,
    required double targetAmount,
    required String visibility,
    required bool isAnonymous,
    DateTime? deadline,
  }) async {
    state = const EditProjectState(isLoading: true);
    try {
      await _repo.updateProject(
        projectId,
        title: title,
        description: description,
        targetAmount: targetAmount,
        visibility: visibility,
        isAnonymous: isAnonymous,
        deadline: deadline,
      );
      state = const EditProjectState(saved: true);
    } catch (e) {
      state = EditProjectState(error: e.toString());
    }
  }

  Future<void> changeStatus({
    required String projectId,
    required String status,
  }) async {
    state = const EditProjectState(isLoading: true);
    try {
      await _repo.updateProject(projectId, status: status);
      state = const EditProjectState(saved: true);
    } catch (e) {
      state = EditProjectState(error: e.toString());
    }
  }

  void reset() => state = const EditProjectState();
}


final editProjectProvider =
    StateNotifierProvider<EditProjectNotifier, EditProjectState>(
  (ref) => EditProjectNotifier(ref.watch(projectsRepositoryProvider)),
);