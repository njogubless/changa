import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Shows the invite code bottom sheet.
/// Call this after creating a chama or from the chama detail screen.
void showInviteCodeSheet(BuildContext context, ChamaModel chama) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cream,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _InviteCodeSheet(chama: chama, parentContext: context),
  );
}

class _InviteCodeSheet extends StatelessWidget {
  final ChamaModel chama;
  final BuildContext parentContext;

  const _InviteCodeSheet({required this.chama, required this.parentContext});

  String get _shareText =>
      'Join my Chama "${chama.name}" on Changa!\n\n'
      'Use invite code: ${chama.inviteCode}\n\n'
      'Download Changa and enter the code to join.';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Chama avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _parseColor(chama.avatarColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  chama.name
                      .trim()
                      .split(' ')
                      .where((e) => e.isNotEmpty)
                      .take(2)
                      .map((e) => e[0].toUpperCase())
                      .join(),
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              chama.name,
              style: AppTextStyles.h3.copyWith(color: AppColors.forest),
            ),
            const SizedBox(height: 4),
            Text(
              'Share this code to invite members',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Invite code display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.forest.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'INVITE CODE',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.green,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chama.inviteCode,
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.forest,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                // Copy button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: chama.inviteCode));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: const Text('Invite code copied ✓'),
                          backgroundColor: AppColors.forest,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copy code'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forest,
                      side: const BorderSide(color: AppColors.forest),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Share button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(text: _shareText),
                      );
                    },
                    icon: const Icon(Icons.share_outlined, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: AppColors.cream,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Share via WhatsApp specifically
            GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await SharePlus.instance.share(ShareParams(text: _shareText));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF25D366).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.message_outlined,
                      color: Color(0xFF25D366),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Share via WhatsApp / SMS',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF25D366),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.forest;
    }
  }
}
