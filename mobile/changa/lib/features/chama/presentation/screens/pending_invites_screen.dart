import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/data/models/invite_models.dart';
import 'package:changa/features/chama/presentation/providers/invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../../core/theme/app_theme.dart';
// import 'invite_provider.dart';
// import 'invite_models.dart';

/// Shown on home screen when user has pending invites.
/// Also accessible as a full screen from notifications.
class PendingInvitesScreen extends ConsumerWidget {
  const PendingInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(pendingInvitesProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Invites'),
        actions: [
          TextButton(
            onPressed: () => _showJoinByCodeSheet(context, ref),
            child: Text(
              'Have a code?',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.mint),
            ),
          ),
        ],
      ),
      body: invitesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(pendingInvitesProvider),
        ),
        data: (invites) => invites.isEmpty
            ? _EmptyInvites(
                onJoinByCode: () => _showJoinByCodeSheet(context, ref),
              )
            : RefreshIndicator(
                color: AppColors.forest,
                onRefresh: () async => ref.invalidate(pendingInvitesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: invites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => InviteCard(invite: invites[i]),
                ),
              ),
      ),
    );
  }
}

// ── Invite card ────────────────────────────────────────────────────────────────

class InviteCard extends ConsumerWidget {
  final ChamaInviteModel invite;
  const InviteCard({super.key, required this.invite});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(inviteActionProvider);
    final isLoading = actionState is InviteActionLoading;

    // Listen for success to show snackbar
    ref.listen(inviteActionProvider, (_, state) {
      if (state is InviteActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.accepted
                  ? 'You joined ${state.chamaName}! 🎉'
                  : 'Invite declined.',
            ),
            backgroundColor:
                state.accepted ? AppColors.forest : AppColors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        ref.read(inviteActionProvider.notifier).reset();
      }
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.sand.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              // Chama avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdAll,
                ),
                child: Center(
                  child: Text(
                    invite.chamaName[0].toUpperCase(),
                    style: AppTextStyles.h3.copyWith(color: AppColors.forest),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.chamaName,
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.forest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invite.invitedByName} invited you',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              // Expiry badge
              _ExpiryBadge(expiresAt: invite.expiresAt),
            ],
          ),

          if (invite.chamaDescription != null) ...[
            const SizedBox(height: 10),
            Text(
              invite.chamaDescription!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.green,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Accept / Decline buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(inviteActionProvider.notifier)
                          .decline(invite.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(inviteActionProvider.notifier)
                          .accept(invite.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.cream),
                        )
                      : const Text('Accept & Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Expiry badge ──────────────────────────────────────────────────────────────

class _ExpiryBadge extends StatelessWidget {
  final DateTime expiresAt;
  const _ExpiryBadge({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    final isUrgent = daysLeft <= 1;
    final color = isUrgent ? AppColors.error : AppColors.sage;
    final label = daysLeft <= 0
        ? 'Expiring soon'
        : daysLeft == 1
            ? '1 day left'
            : '$daysLeft days left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyInvites extends StatelessWidget {
  final VoidCallback onJoinByCode;
  const _EmptyInvites({required this.onJoinByCode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.sage.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline,
                color: AppColors.sage,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No pending invites',
              style: AppTextStyles.h4.copyWith(color: AppColors.forest),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask a chama admin to invite you\nby your phone number.',
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.green),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onJoinByCode,
              icon: const Icon(Icons.tag, size: 16),
              label: const Text('I have an invite code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, color: AppColors.sand, size: 40),
          const SizedBox(height: 16),
          Text('Could not load invites',
              style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

// ── Join by code sheet ─────────────────────────────────────────────────────────

void _showJoinByCodeSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _JoinByCodeSheet(),
  );
}

class _JoinByCodeSheet extends ConsumerStatefulWidget {
  const _JoinByCodeSheet();

  @override
  ConsumerState<_JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends ConsumerState<_JoinByCodeSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinByCodeProvider);
    final isLoading = state is JoinByCodeLoading;
    final error = state is JoinByCodeError ? state.message : null;

    // Navigate away on success
    ref.listen(joinByCodeProvider, (_, s) {
      if (s is JoinByCodeSuccess) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome to ${s.chamaName}! 🎉'),
            backgroundColor: AppColors.forest,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        // TODO: navigate to the chama detail screen
        // context.push(AppRoutes.chamaDetail(s.chamaId));
      }
    });

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 20, 24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('Join with a code',
              style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
          const SizedBox(height: 6),
          Text(
            'Paste the invite code shared with you.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.characters,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.forest,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              hintText: 'CHNG-XXXX',
              hintStyle: AppTextStyles.h3.copyWith(
                color: AppColors.sand,
                letterSpacing: 6,
              ),
              prefixIcon: const Icon(Icons.tag, color: AppColors.green, size: 20),
            ),
          ),

          if (error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error,
                    style: AppTextStyles.caption.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: isLoading
                ? null
                : () => ref.read(joinByCodeProvider.notifier).join(_ctrl.text),
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.cream),
                  )
                : const Text('Join chama'),
          ),
        ],
      ),
    );
  }
}
