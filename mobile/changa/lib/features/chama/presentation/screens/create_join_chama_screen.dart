import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:changa/features/chama/presentation/screens/invite_code_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateChamaScreen extends ConsumerStatefulWidget {
  const CreateChamaScreen({super.key});

  @override
  ConsumerState<CreateChamaScreen> createState() => _CreateChamaScreenState();
}

class _CreateChamaScreenState extends ConsumerState<CreateChamaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedColor = '#1B4332';
  String? _errorMessage;

  static const _colors = [
    '#1B4332', '#2D6A4F', '#52796F', '#B5838D',
    '#6B4226', '#1A535C', '#4A4E69', '#C77DFF',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    await ref.read(createChamaProvider.notifier).create(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          avatarColor: _selectedColor,
        );

    if (!mounted) return;

    final state = ref.read(createChamaProvider);
    if (state.created != null) {
      final chama = state.created!;
      ref.read(chamaListProvider.notifier).addChama(chama);
      ref.read(createChamaProvider.notifier).reset();

      context.go('/chamas/${chama.id}');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showInviteCodeSheet(context, chama);
      });
    } else if (state.error != null) {
      setState(() => _errorMessage = state.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createChamaProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        title: const Text('Create a Chama'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

              _Label('Chama name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'e.g. Nairobi Youth Group',
                  prefixIcon: Icon(Icons.people_outline,
                      color: AppColors.green, size: 20),
                ),
                validator: (v) => v == null || v.trim().length < 3
                    ? 'Name must be at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 20),

              _Label('Description (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'What is this Chama about?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

              _Label('Chama colour'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((hex) {
                  final selected = hex == _selectedColor;
                  final color =
                      Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.cream
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.cream),
                      )
                    : const Text('Create Chama'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: AppColors.forest,
          letterSpacing: 0.8,
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error)),
            ),
          ],
        ),
      );
}


class JoinChamaScreen extends ConsumerStatefulWidget {
  const JoinChamaScreen({super.key});

  @override
  ConsumerState<JoinChamaScreen> createState() => _JoinChamaScreenState();
}

class _JoinChamaScreenState extends ConsumerState<JoinChamaScreen> {
  final _codeCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter an invite code');
      return;
    }
    setState(() => _errorMessage = null);

    await ref.read(joinChamaProvider.notifier).join(code);

    if (!mounted) return;

    final state = ref.read(joinChamaProvider);
    if (state.joined != null) {
      ref.read(chamaListProvider.notifier).addChama(state.joined!);
      ref.read(joinChamaProvider.notifier).reset();
      context.go('/chamas/${state.joined!.id}');
    } else if (state.error != null) {
      setState(() => _errorMessage = state.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(joinChamaProvider).isLoading;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        title: const Text('Join a Chama'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.sage.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_outlined,
                      color: AppColors.forest, size: 36),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Enter invite code',
                style: AppTextStyles.h2.copyWith(color: AppColors.forest),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask the Chama owner to share their invite code with you.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.green, height: 1.5),
              ),
              const SizedBox(height: 32),
        
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],
        
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.forest,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'CHNG-XXXX',
                  hintStyle: AppTextStyles.h3.copyWith(
                    color: AppColors.sand,
                    letterSpacing: 4,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.sand),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.sand),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: AppColors.forest, width: 2),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
        
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.cream),
                      )
                    : const Text('Join Chama'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

