import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/data/models/auth_models.dart';
import 'package:flutter/material.dart';


class ProfileHeader extends StatelessWidget {
  final UserModel user;
  const ProfileHeader({super.key, required this.user});

  String get _initials => user.fullName
      .trim()
      .split(' ')
      .where((e) => e.isNotEmpty)
      .take(2)
      .map((e) => e[0].toUpperCase())
      .join();

  Color get _avatarColor {
    const colors = [
      AppColors.forest,
      Color(0xFF2D6A4F),
      Color(0xFF1B4332),
      AppColors.mpesaGreen,
      Color(0xFF52796F),
    ];
    return colors[user.fullName.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _ProfileBgPainter())),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              // Avatar
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: _avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cream.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w800,
                      fontSize: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.fullName,
                style: AppTextStyles.h3.copyWith(color: AppColors.cream),
              ),
              const SizedBox(height: 4),
              Text(
                user.email,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.mint),
              ),
              const SizedBox(height: 2),
              Text(
                user.phone,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.mint.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width + 30, size.height * 0.2),
      120,
      Paint()..color = AppColors.sage.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(-40, size.height * 0.8),
      100,
      Paint()..color = AppColors.mint.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
