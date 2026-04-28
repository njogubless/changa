

import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/screens/policy_view_screen.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  void _openPolicy(BuildContext context, PolicyType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PolicyViewerScreen(type: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.forest,
            side: const BorderSide(color: AppColors.green, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.green,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.forest,
                    height: 1.5,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _openPolicy(
                          context,
                          PolicyType.termsOfService,
                        ),
                ),
                const TextSpan(text: ' and '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.forest,
                    height: 1.5,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _openPolicy(
                          context,
                          PolicyType.privacyPolicy,
                        ),
                ),
                const TextSpan(text: '. I confirm I am 18 years or older.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}