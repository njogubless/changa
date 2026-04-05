import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/providers/edit_project_provider.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:changa/features/projects/presentation/widgets/project_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class EditProjectScreen extends ConsumerStatefulWidget {
  final ProjectModel project;
  const EditProjectScreen({super.key, required this.project});

  @override
  ConsumerState<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends ConsumerState<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late String _visibility;
  late bool _isAnonymous;
  DateTime? _deadline;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.project.title);
    _descCtrl = TextEditingController(text: widget.project.description ?? '');
    _amountCtrl = TextEditingController(
        text: widget.project.targetAmount.toInt().toString());
    //_visibility = widget.project.visibility.name;
    _isAnonymous = widget.project.isAnonymous;
    _deadline = widget.project.deadline;
  }

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

    await ref.read(editProjectProvider.notifier).update(
          projectId: widget.project.id,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          targetAmount: double.parse(_amountCtrl.text.replaceAll(',', '')),
          visibility: _visibility,
          isAnonymous: _isAnonymous,
          deadline: _deadline,
        );

    if (!mounted) return;

    final state = ref.read(editProjectProvider);
    if (state.saved) {
      ref.invalidate(projectDetailProvider(widget.project.id));
      ref.read(projectsNotifierProvider.notifier).refresh();
      ScaffoldMessenger.of(context)
          .showSnackBar(_snackBar('Project updated successfully'));
      context.pop();
    } else if (state.error != null) {
      setState(() => _errorMessage = _friendlyError(state.error!));
    }
  }

  Future<void> _confirmStatusChange(String action) async {
    final isCancel = action == 'cancel';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCancel ? 'Cancel project?' : 'Pause project?',
          style: AppTextStyles.h3.copyWith(color: AppColors.forest),
        ),
        content: Text(
          isCancel
              ? 'This will permanently cancel the project. This cannot be undone.'
              : 'Contributors will not be able to contribute until you resume.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.green)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isCancel ? AppColors.error : AppColors.gold,
              foregroundColor: Colors.white,
            ),
            child: Text(isCancel ? 'Yes, cancel' : 'Pause'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(editProjectProvider.notifier).changeStatus(
          projectId: widget.project.id,
          status: isCancel ? 'cancelled' : 'paused',
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      _snackBar(isCancel ? 'Project cancelled' : 'Project paused'),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(editProjectProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
        title: const Text('Edit project'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _submit,
            child: Text(
              'Save',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isLoading
                    ? AppColors.cream.withValues(alpha: 0.4)
                    : AppColors.mint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                ProjectErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

              const ProjectSectionLabel('Project title'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                    hintText: 'e.g. Harambee ya John na Mary'),
                validator: (v) => v == null || v.trim().length < 3
                    ? 'Title must be at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 20),

              const ProjectSectionLabel('Description (optional)'),
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

              const ProjectSectionLabel('Target amount (KES)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                    hintText: 'e.g. 50000', prefixText: 'KES '),
                validator: (v) {
                  final amount =
                      double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (amount == null || amount < 100) {
                    return 'Minimum amount is KES 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              const ProjectSectionLabel('Visibility'),
              const SizedBox(height: 10),
              Row(children: [
                ProjectVisibilityOption(
                  label: 'Public',
                  subtitle: 'Anyone can see',
                  icon: Icons.public,
                  selected: _visibility == 'public',
                  onTap: () => setState(() => _visibility = 'public'),
                ),
                const SizedBox(width: 12),
                ProjectVisibilityOption(
                  label: 'Private',
                  subtitle: 'Invite only',
                  icon: Icons.lock_outline,
                  selected: _visibility == 'private',
                  onTap: () => setState(() => _visibility = 'private'),
                ),
              ]),
              const SizedBox(height: 20),

              ProjectToggleRow(
                title: 'Anonymous contributions',
                subtitle: 'Contributor names hidden from each other',
                value: _isAnonymous,
                onChanged: (v) => setState(() => _isAnonymous = v),
              ),
              const SizedBox(height: 16),

              const ProjectSectionLabel('Deadline (optional)'),
              const SizedBox(height: 8),
              ProjectDeadlinePicker(
                deadline: _deadline,
                onTap: () async {
                  final picked = await pickProjectDeadline(
                    context,
                    initial: _deadline,
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
                onClear: () => setState(() => _deadline = null),
              ),
              const SizedBox(height: 32),

              if (widget.project.raisedAmount == 0) ...[
                const ProjectSectionLabel('Danger zone'),
                const SizedBox(height: 8),
                ProjectDangerAction(
                  icon: Icons.pause_circle_outline,
                  label: 'Pause project',
                  subtitle: 'Temporarily stop contributions',
                  color: AppColors.gold,
                  onTap: () => _confirmStatusChange('pause'),
                ),
                const SizedBox(height: 8),
                ProjectDangerAction(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel project',
                  subtitle: 'This cannot be undone',
                  color: AppColors.error,
                  onTap: () => _confirmStatusChange('cancel'),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.cream),
                      )
                    : const Text('Save changes'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.contains('Network') || raw.contains('connection')) {
      return 'No internet connection.';
    }
    if (raw.contains('403') || raw.contains('forbidden')) {
      return 'You do not have permission to edit this project.';
    }
    return 'Could not update project. Please try again.';
  }

  SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.forest,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}