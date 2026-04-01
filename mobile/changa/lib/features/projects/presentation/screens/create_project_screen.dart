import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _visibility = 'public';
  bool _isAnonymous = false;
  DateTime? _deadline;
  String? _errorMessage;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    await ref.read(createProjectProvider.notifier).create(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          targetAmount: double.parse(_amountCtrl.text.replaceAll(',', '')),
          visibility: _visibility,
          isAnonymous: _isAnonymous,
          deadline: _deadline,
        );

    final state = ref.read(createProjectProvider);
    if (!mounted) return;

    if (state.created != null) {
      // Refresh the projects list
      ref.read(projectsNotifierProvider.notifier).refresh();
      // Navigate to the new project
      context.pushReplacement(
          AppRoutes.projectDetailPath(state.created!.id));
    } else if (state.error != null) {
      setState(() => _errorMessage = _friendlyError(state.error!));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('100')) return 'Target must be at least KES 100.';
    if (raw.contains('Network')) return 'No internet connection.';
    return 'Could not create project. Please try again.';
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.forest,
            onPrimary: AppColors.cream,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createProjectProvider);
    final isLoading = createState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('New project'),
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
              // Error
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

     
              _SectionLabel('Project title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'e.g. Harambee ya John na Mary',
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

             
              _SectionLabel('Description (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Tell people what this project is about...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),

             
              _SectionLabel('Target amount (KES)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'e.g. 50000',
                  prefixText: 'KES ',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Amount is required';
                  final amount = double.tryParse(v.replaceAll(',', ''));
                  if (amount == null || amount < 100) {
                    return 'Minimum amount is KES 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

       
              _SectionLabel('Visibility'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _VisibilityOption(
                    label: 'Public',
                    subtitle: 'Anyone can see',
                    icon: Icons.public,
                    selected: _visibility == 'public',
                    onTap: () => setState(() => _visibility = 'public'),
                  ),
                  const SizedBox(width: 12),
                  _VisibilityOption(
                    label: 'Private',
                    subtitle: 'Invite only',
                    icon: Icons.lock_outline,
                    selected: _visibility == 'private',
                    onTap: () => setState(() => _visibility = 'private'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

         
              _ToggleRow(
                title: 'Anonymous contributions',
                subtitle: 'Contributor names hidden from each other',
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v),
              ),
              const SizedBox(height: 16),


              _SectionLabel('Deadline (optional)'),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: AppColors.sand),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: _deadline != null
                            ? AppColors.forest
                            : AppColors.sand,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _deadline != null
                            ? _formatDate(_deadline!)
                            : 'No deadline',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _deadline != null
                              ? AppColors.forest
                              : Colors.grey.shade400,
                        ),
                      ),
                      const Spacer(),
                      if (_deadline != null)
                        GestureDetector(
                          onTap: () => setState(() => _deadline = null),
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.sand),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

  
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.cream,
                        ),
                      )
                    : const Text('Create project'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}



class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTextStyles.label.copyWith(
        color: AppColors.forest,
        letterSpacing: 0.8,
      ),
    );
  }
}



class _VisibilityOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.forest.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.sand,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.forest : AppColors.sand,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.h4.copyWith(
                  color: selected ? AppColors.forest : AppColors.green,
                ),
              ),
              Text(
                subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.green.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.sand),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.green.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.forest,
          ),
        ],
      ),
    );
  }
}



class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
