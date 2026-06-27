import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/presentation/providers/invite_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../../../core/theme/app_theme.dart';
// import 'invite_provider.dart';

/// Drop this widget at the top of your chama home screen.
/// It only renders when the user has pending invites.
/// Tapping it opens the full invites screen.
class InviteBanner extends ConsumerWidget {
  final VoidCallback onTap;
  const InviteBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inviteBadgeCountProvider);
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.1),
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // Icon with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: const Icon(
                    Icons.mail_outline,
                    color: AppColors.gold,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? 'You have 1 chama invite'
                        : 'You have $count chama invites',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.earth,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tap to review and accept',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.earth.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.gold,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small dot badge for the bottom navigation bar.
/// Add this on top of the Home nav icon.
class InviteNavBadge extends ConsumerWidget {
  final Widget child;
  const InviteNavBadge({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(inviteBadgeCountProvider);
    if (count == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
