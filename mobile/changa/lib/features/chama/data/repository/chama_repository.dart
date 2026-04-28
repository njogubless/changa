import 'package:changa/core/network/api_client.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';

import 'package:changa/features/projects/data/models/project_models.dart';

class ChamaRepository {
  final ApiClient _api;
  ChamaRepository(this._api);



  Future<ChamaListResponse> getMyChamas() async {
    final response = await _api.get('/chamas');
    return ChamaListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChamaModel> getChama(String id) async {
    final response = await _api.get('/chamas/$id');
    return ChamaModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChamaModel> createChama({
    required String name,
    String? description,
    String avatarColor = '#1B4332',
  }) async {
    final response = await _api.post('/chamas', data: {
      'name': name,
      if (description != null) 'description': description,
      'avatar_color': avatarColor,
    });
    return ChamaModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChamaModel> updateChama(
    String id, {
    String? name,
    String? description,
    String? avatarColor,
  }) async {
    final response = await _api.put('/chamas/$id', data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (avatarColor != null) 'avatar_color': avatarColor,
    });
    return ChamaModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ChamaModel> joinChama(String inviteCode) async {
    final response = await _api.post('/chamas/join', data: {
      'invite_code': inviteCode.trim().toUpperCase(),
    });
    return ChamaModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> leaveChama(String chamaId) async {
    await _api.post('/chamas/$chamaId/leave');
  }

  Future<List<ChamaMemberModel>> getMembers(String chamaId) async {
    final response = await _api.get('/chamas/$chamaId/members');
    return (response.data as List)
        .map((e) => ChamaMemberModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeMember(String chamaId, String userId) async {
    await _api.delete('/chamas/$chamaId/members/$userId');
  }

  Future<ChamaModel> regenerateInviteCode(String chamaId) async {
    final response =
        await _api.post('/chamas/$chamaId/regenerate-code');
    return ChamaModel.fromJson(response.data as Map<String, dynamic>);
  }



  Future<ProjectListResponse> getChamaProjects(
    String chamaId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get(
      '/chamas/$chamaId/projects',
      params: {'page': page, 'page_size': pageSize},
    );
    return ProjectListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<ProjectModel> createChamaProject({
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
    final response =
        await _api.post('/chamas/$chamaId/projects', data: {
      'title': title,
      if (description != null) 'description': description,
      'target_amount': targetAmount,
      'payment_type': paymentType,
      'payment_number': paymentNumber,
      if (paymentName != null) 'payment_name': paymentName,
      if (accountReference != null) 'account_reference': accountReference,
      'is_anonymous': isAnonymous,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    return ProjectModel.fromJson(response.data as Map<String, dynamic>);
  }
}