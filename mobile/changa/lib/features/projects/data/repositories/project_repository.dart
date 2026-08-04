

import 'package:changa/core/constants/api_constants.dart';
import 'package:changa/core/network/api_client.dart';
import 'package:changa/features/projects/data/models/project_models.dart';

class ProjectsRepository {
  final ApiClient _api;
  ProjectsRepository(this._api);

  Future<ProjectListResponse> getMyProjects({
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _api.get(
      ApiConstants.myProjects,
      params: {'page': page, 'page_size': pageSize},
    );
    return ProjectListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  // Same endpoint as getMyProjects (there is only one cross-chama listing
  // route server-side) — kept as a separate method because
  // projectsNotifierProvider drives paging/search state that
  // getMyProjects's caller doesn't need. See API-01.
  Future<ProjectListResponse> getProjects({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final response = await _api.get(
      ApiConstants.myProjects,
      params: {
        'page': page,
        'page_size': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return ProjectListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<ProjectModel> getProject(String id) async {
    final response = await _api.get(ApiConstants.projectById(id));
    return ProjectModel.fromJson(response.data as Map<String, dynamic>);
  }

 Future<ProjectModel> updateProject(
  String id, {
  String? title,
  String? description,
  double? targetAmount,
  bool? isAnonymous,
  DateTime? deadline,
  String? status,
}) async {
  final response = await _api.put(
    ApiConstants.projectById(id),
    data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (targetAmount != null) 'target_amount': targetAmount,
      if (isAnonymous != null) 'is_anonymous': isAnonymous,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
      if (status != null) 'status': status,
    },
  );
  return ProjectModel.fromJson(response.data as Map<String, dynamic>);
}

  Future<List<ContributorModel>> getContributors(String id) async {
    final response = await _api.get(ApiConstants.projectContributors(id));
    return (response.data as List)
        .map((e) => ContributorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
