import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';



class ProfileSectionHeader extends StatelessWidget {
  final String title;
  const ProfileSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}


class ProfileMenuCard extends StatelessWidget {
  final List<ProfileMenuTileData> items;
  const ProfileMenuCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          return Column(
            children: [
              _ProfileMenuTile(data: entry.value),
              if (entry.key < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.sand.withValues(alpha: 0.5),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}



class ProfileMenuTileData {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const ProfileMenuTileData({
    required this.icon,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
  });
}


class _ProfileMenuTile extends StatelessWidget {
  final ProfileMenuTileData data;
  const _ProfileMenuTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: data.onTap != null
          ? () {
              HapticFeedback.selectionClick();
              data.onTap!();
            }
          : null,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.forest.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(data.icon, color: AppColors.forest, size: 18),
      ),
      title: Text(
        data.label,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest),
      ),
      subtitle: data.value != null
          ? Text(
              data.value!,
              style: AppTextStyles.caption.copyWith(color: AppColors.green),
            )
          : null,
      trailing: data.trailing ??
          (data.onTap != null
              ? const Icon(Icons.chevron_right, color: AppColors.sand, size: 20)
              : null),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}



class ProfileLogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const ProfileLogoutButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Text(
              'Sign out',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.sand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}



SnackBar buildSnackBar(String message, {bool isError = false}) => SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.forest,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
