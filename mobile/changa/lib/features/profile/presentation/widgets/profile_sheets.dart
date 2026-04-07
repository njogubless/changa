import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_menu.dart';

// ── Edit profile sheet ─────────────────────────────────────────────────────

void showEditProfileSheet(
  BuildContext context,
  WidgetRef ref,
  String currentName,
) {
  final nameCtrl = TextEditingController(text: currentName);
  final formKey = GlobalKey<FormState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BottomSheetHandle(),
                const SizedBox(height: 20),
                Text(
                  'Edit profile',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppColors.green,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator:
                        (v) =>
                            v == null || v.trim().length < 2
                                ? 'Name is too short'
                                : null,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    // await ref.read(authRepositoryProvider).updateProfile(fullName: nameCtrl.text.trim());
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(buildSnackBar('Profile updated'));
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        ),
  );
}

void showChangePasswordSheet(BuildContext context, WidgetRef ref) {
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var isLoading = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (ctx) => StatefulBuilder(
          builder:
              (ctx, setState) => Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BottomSheetHandle(),
                      const SizedBox(height: 20),
                      Text(
                        'Change password',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: currentCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Current password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppColors.green,
                          ),
                        ),
                        validator:
                            (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(
                            Icons.lock_reset_outlined,
                            color: AppColors.green,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 8)
                            return 'Min 8 characters';
                          if (!v.contains(RegExp(r'[A-Za-z]')))
                            return 'Must contain a letter';
                          if (!v.contains(RegExp(r'\d')))
                            return 'Must contain a number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed:
                            isLoading
                                ? null
                                : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setState(() => isLoading = true);
                                  try {
                                    await ref
                                        .read(authRepositoryProvider)
                                        .changePassword(
                                          currentPassword: currentCtrl.text,
                                          newPassword: newCtrl.text,
                                        );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        buildSnackBar(
                                          'Password changed successfully',
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setState(() => isLoading = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        buildSnackBar(
                                          'Incorrect current password',
                                          isError: true,
                                        ),
                                      );
                                    }
                                  }
                                },
                        child:
                            isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.cream,
                                  ),
                                )
                                : const Text('Update password'),
                      ),
                    ],
                  ),
                ),
              ),
        ),
  );
}

void showEditPhoneSheet(
  BuildContext context,
  WidgetRef ref,
  String currentPhone,
) {
  final phoneCtrl = TextEditingController(text: currentPhone);
  final formKey = GlobalKey<FormState>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BottomSheetHandle(),
                const SizedBox(height: 20),
                Text(
                  'M-Pesa number',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest),
                ),
                const SizedBox(height: 4),
                Text(
                  'Used for all contributions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'M-Pesa number',
                      prefixIcon: Icon(
                        Icons.phone_android,
                        color: AppColors.mpesaGreen,
                      ),
                      hintText: '254712345678',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!RegExp(r'^254[17]\d{8}$').hasMatch(v)) {
                        return 'Use format 254XXXXXXXXX';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(buildSnackBar('M-Pesa number updated'));
                  },
                  child: const Text('Save number'),
                ),
              ],
            ),
          ),
        ),
  );
}

void showLogoutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sign out',
            style: AppTextStyles.h3.copyWith(color: AppColors.forest),
          ),
          content: Text(
            'Are you sure you want to sign out of Changa?',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.green,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authNotifierProvider.notifier).logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign out'),
            ),
          ],
        ),
  );
}
