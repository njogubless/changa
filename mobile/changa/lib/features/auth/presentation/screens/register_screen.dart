import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/auth/presentation/widgets/auth_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _errorMessage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _errorMessage = null);

  debugPrint('>>> SUBMIT STARTED');

  try {
    await ref.read(authNotifierProvider.notifier).register(
          fullName: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    debugPrint('>>> REGISTER CALL COMPLETED');
  } catch (e, st) {
    debugPrint('>>> REGISTER THREW: $e');
    debugPrint('>>> STACK: $st');
  }

  if (!mounted) return;
  debugPrint('>>> MOUNTED CHECK PASSED');

  final state = ref.read(authNotifierProvider);
  debugPrint('>>> STATE AFTER REGISTER: $state');

  if (state is AuthError) {
    setState(() => _errorMessage = _friendlyError(state.message));
  }
}

  String _friendlyError(String raw) {
    if (raw.contains('Email already')) return 'This email is already registered.';
    if (raw.contains('Phone') && raw.contains('registered')) {
      return 'This phone number is already registered.';
    }
    if (raw.contains('Network') || raw.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Something went wrong. Please try again.';
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'Phone number is required';
    final cleaned = v.replaceAll(' ', '');
    if (!RegExp(r'^254[17]\d{8}$').hasMatch(cleaned)) {
      return 'Use format 254XXXXXXXXX (e.g. 254712345678)';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Must be at least 8 characters';
    if (!v.contains(RegExp(r'[A-Za-z]'))) return 'Must contain a letter';
    if (!v.contains(RegExp(r'\d'))) return 'Must contain a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                const AuthHeader(
                  title: 'Create your\naccount',
                  subtitle: 'Join thousands contributing together in Kenya',
                ),
                const SizedBox(height: 40),

                if (_errorMessage != null) ...[
                  ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 20),
                ],

                // Full name
                AuthTextField(
                  label: 'FULL NAME',
                  hint: 'Amina Wanjiru',
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_emailFocus),
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.green,
                    size: 20,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Name is required';
                    if (v.trim().length < 2) return 'Name is too short';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email
                AuthTextField(
                  label: 'EMAIL',
                  hint: 'amina@example.com',
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_phoneFocus),
                  prefixIcon: const Icon(
                    Icons.mail_outline,
                    color: AppColors.green,
                    size: 20,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Phone — M-Pesa number
                AuthTextField(
                  label: 'M-PESA NUMBER',
                  hint: '254712345678',
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  prefixIcon: const Icon(
                    Icons.phone_android,
                    color: AppColors.mpesaGreen,
                    size: 20,
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Start with 254 — this is your M-Pesa number',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password
                AuthTextField(
                  label: 'PASSWORD',
                  hint: '8+ characters with a number',
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    color: AppColors.green,
                    size: 20,
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 32),

                // Submit
                LoadingButton(
                  onPressed: _submit,
                  isLoading: isLoading,
                  label: 'Create account',
                ),
                const SizedBox(height: 24),

                // Sign in link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.green,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => context.go(AppRoutes.login),
                        child: Text(
                          'Sign in',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.forest,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
