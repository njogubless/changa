

import 'package:changa/features/chama/data/models/invite_models.dart';
import 'package:changa/features/chama/data/repository/invite_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(null), // replace null with ref.watch(apiClientProvider)
);

// ── Pending invites (user's notification inbox) ───────────────────────────────

final pendingInvitesProvider =
    FutureProvider.autoDispose<List<ChamaInviteModel>>((ref) async {
  return ref.watch(inviteRepositoryProvider).getMyInvites(status: 'pending');
});

// ── Invite badge count (for bottom nav dot) ───────────────────────────────────

final inviteBadgeCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(pendingInvitesProvider).when(
        data: (invites) => invites.length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

// ── Accept/Decline state ──────────────────────────────────────────────────────

sealed class InviteActionState {
  const InviteActionState();
}
class InviteActionIdle    extends InviteActionState { const InviteActionIdle(); }
class InviteActionLoading extends InviteActionState { const InviteActionLoading(); }
class InviteActionSuccess extends InviteActionState {
  final String chamaName;
  final bool accepted;
  const InviteActionSuccess(this.chamaName, {required this.accepted});
}
class InviteActionError   extends InviteActionState {
  final String message;
  const InviteActionError(this.message);
}

class InviteActionNotifier extends StateNotifier<InviteActionState> {
  final InviteRepository _repo;
  final Ref _ref;

  InviteActionNotifier(this._repo, this._ref) : super(const InviteActionIdle());

  Future<void> accept(String inviteId) async {
    state = const InviteActionLoading();
    try {
      final result = await _repo.acceptInvite(inviteId);
      // Refresh the chama list so it appears on home screen immediately
      _ref.invalidate(pendingInvitesProvider);
      state = InviteActionSuccess(
        result['chama_name'] as String,
        accepted: true,
      );
    } catch (e) {
      state = InviteActionError(_friendlyError(e.toString()));
    }
  }

  Future<void> decline(String inviteId) async {
    state = const InviteActionLoading();
    try {
      await _repo.declineInvite(inviteId);
      _ref.invalidate(pendingInvitesProvider);
      state = const InviteActionSuccess('', accepted: false);
    } catch (e) {
      state = InviteActionError(_friendlyError(e.toString()));
    }
  }

  void reset() => state = const InviteActionIdle();

  String _friendlyError(String raw) {
    if (raw.contains('expired')) return 'This invite has expired.';
    if (raw.contains('already')) return 'You are already a member.';
    if (raw.contains('Network')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }
}

final inviteActionProvider =
    StateNotifierProvider.autoDispose<InviteActionNotifier, InviteActionState>(
  (ref) => InviteActionNotifier(ref.watch(inviteRepositoryProvider), ref),
);

// ── Join by code state ────────────────────────────────────────────────────────

sealed class JoinByCodeState {
  const JoinByCodeState();
}
class JoinByCodeIdle    extends JoinByCodeState { const JoinByCodeIdle(); }
class JoinByCodeLoading extends JoinByCodeState { const JoinByCodeLoading(); }
class JoinByCodeSuccess extends JoinByCodeState {
  final String chamaName;
  final String chamaId;
  const JoinByCodeSuccess({required this.chamaName, required this.chamaId});
}
class JoinByCodeError   extends JoinByCodeState {
  final String message;
  const JoinByCodeError(this.message);
}

class JoinByCodeNotifier extends StateNotifier<JoinByCodeState> {
  final InviteRepository _repo;
  final Ref _ref;

  JoinByCodeNotifier(this._repo, this._ref) : super(const JoinByCodeIdle());

  Future<void> join(String code) async {
    state = const JoinByCodeLoading();
    try {
      final result = await _repo.joinByCode(code);
      _ref.invalidate(pendingInvitesProvider);
      state = JoinByCodeSuccess(
        chamaName: result['chama_name'] as String,
        chamaId: result['chama_id'] as String,
      );
    } catch (e) {
      state = JoinByCodeError(_friendlyError(e.toString()));
    }
  }

  void reset() => state = const JoinByCodeIdle();

  String _friendlyError(String raw) {
    if (raw.contains('Invalid') || raw.contains('404')) {
      return 'Invalid invite code. Double-check and try again.';
    }
    if (raw.contains('expired')) return 'This invite code has expired.';
    if (raw.contains('already')) return 'You are already a member of this chama.';
    if (raw.contains('Network')) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }
}

final joinByCodeProvider =
    StateNotifierProvider.autoDispose<JoinByCodeNotifier, JoinByCodeState>(
  (ref) => JoinByCodeNotifier(ref.watch(inviteRepositoryProvider), ref),
);

// ── Generate code state (admin) ───────────────────────────────────────────────

final generateCodeProvider =
    FutureProvider.autoDispose.family<GeneratedCodeModel, String>((ref, chamaId) async {
  return ref.watch(inviteRepositoryProvider).generateInviteCode(chamaId);
});
