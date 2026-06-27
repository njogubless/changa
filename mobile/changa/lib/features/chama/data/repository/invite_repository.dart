

import 'package:changa/features/chama/data/models/invite_models.dart';

class InviteRepository {
  final dynamic _api; // ApiClient
  InviteRepository(this._api);

  // ── Admin actions ────────────────────────────────────────────────────────────

  /// Invite someone to a chama by their phone number
  Future<Map<String, dynamic>> inviteByPhone({
    required String chamaId,
    required String phone,
  }) async {
    final response = await _api.post(
      '/chamas/$chamaId/members/invite',
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Generate a shareable invite code for a chama
  Future<GeneratedCodeModel> generateInviteCode(String chamaId) async {
    final response = await _api.post(
      '/chamas/$chamaId/members/invite-code',
    );
    return GeneratedCodeModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// List members of a chama, optionally filtered by status
  Future<List<dynamic>> listMembers(
    String chamaId, {
    String? status, // 'pending' | null (all active)
  }) async {
    final response = await _api.get(
      '/chamas/$chamaId/members',
      params: status != null ? {'status': status} : null,
    );
    return response.data as List;
  }

  /// Remove a member from a chama
  Future<void> removeMember({
    required String chamaId,
    required String userId,
  }) async {
    await _api.delete('/chamas/$chamaId/members/$userId');
  }

  // ── User actions ─────────────────────────────────────────────────────────────

  /// Get current user's pending invites (notification inbox)
  Future<List<ChamaInviteModel>> getMyInvites({
    String status = 'pending',
  }) async {
    final response = await _api.get(
      '/chamas/me/invites',
      params: {'status': status},
    );
    return (response.data as List)
        .map((e) => ChamaInviteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Accept a phone invite
  Future<Map<String, dynamic>> acceptInvite(String inviteId) async {
    final response = await _api.post('/chamas/me/invites/$inviteId/accept');
    return response.data as Map<String, dynamic>;
  }

  /// Decline a phone invite
  Future<void> declineInvite(String inviteId) async {
    await _api.post('/chamas/me/invites/$inviteId/decline');
  }

  /// Join a chama by pasting an invite code
  Future<Map<String, dynamic>> joinByCode(String inviteCode) async {
    final response = await _api.post(
      '/chamas/join',
      data: {'invite_code': inviteCode.trim().toUpperCase()},
    );
    return response.data as Map<String, dynamic>;
  }
}
