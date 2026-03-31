import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/data/repositories/project_repository.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── State ──────────────────────────────────────────────────────────────────
class EditProjectState {
  final bool isLoading;
  final String? error;
  final bool saved;
  const EditProjectState({
    this.isLoading = false,
    this.error,
    this.saved = false,
  });
}

class EditProjectNotifier extends StateNotifier<EditProjectState> {
  final ProjectsRepository _repo;
  EditProjectNotifier(this._repo) : super(const EditProjectState());

  Future<void> update({
    required String projectId,
    required String title,
    String? description,
    required double targetAmount,
    required String visibility,
    required bool isAnonymous,
    DateTime? deadline,
  }) async {
    state = const EditProjectState(isLoading: true);
    try {
      await _repo.updateProject(
        projectId, // ← positional, not named
        title: title,
        description: description,
        targetAmount: targetAmount,
        visibility: visibility,
        isAnonymous: isAnonymous,
        deadline: deadline,
        // status not passed here — only for pause/cancel
      );
      state = const EditProjectState(saved: true);
    } catch (e) {
      state = EditProjectState(error: e.toString());
    }
  }

  void reset() => state = const EditProjectState();

  Future<void> changeStatus({
    required String projectId,
    required String status,
  }) async {
    state = const EditProjectState(isLoading: true);
    try {
      await _repo.updateProject(projectId, status: status);
      state = const EditProjectState(saved: true);
    } catch (e) {
      state = EditProjectState(error: e.toString());
    }
  }
}

final editProjectProvider =
    StateNotifierProvider<EditProjectNotifier, EditProjectState>(
      (ref) => EditProjectNotifier(ref.watch(projectsRepositoryProvider)),
    );

// ── Screen ─────────────────────────────────────────────────────────────────
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
      text: widget.project.targetAmount.toInt().toString(),
    );
    _visibility = widget.project.visibility.name;
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

    await ref
        .read(editProjectProvider.notifier)
        .update(
          projectId: widget.project.id,
          title: _titleCtrl.text.trim(),
          description:
              _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Project updated successfully'),
          backgroundColor: AppColors.forest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      context.pop();
    } else if (state.error != null) {
      setState(() => _errorMessage = _friendlyError(state.error!));
    }
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

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder:
          (context, child) => Theme(
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
    final editState = ref.watch(editProjectProvider);
    final isLoading = editState.isLoading;

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
                color:
                    isLoading
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
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                        color:
                            _deadline != null
                                ? AppColors.forest
                                : AppColors.sand,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _deadline != null
                            ? _formatDate(_deadline!)
                            : 'No deadline',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color:
                              _deadline != null
                                  ? AppColors.forest
                                  : Colors.grey.shade400,
                        ),
                      ),
                      const Spacer(),
                      if (_deadline != null)
                        GestureDetector(
                          onTap: () => setState(() => _deadline = null),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.sand,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Danger zone — only if no contributions yet
              if (widget.project.raisedAmount == 0) ...[
                _SectionLabel('Danger zone'),
                const SizedBox(height: 8),
                _DangerAction(
                  icon: Icons.pause_circle_outline,
                  label: 'Pause project',
                  subtitle: 'Temporarily stop contributions',
                  color: AppColors.gold,
                  onTap: () => _confirmStatusChange(context, 'pause'),
                ),
                const SizedBox(height: 8),
                _DangerAction(
                  icon: Icons.cancel_outlined,
                  label: 'Cancel project',
                  subtitle: 'This cannot be undone',
                  color: AppColors.error,
                  onTap: () => _confirmStatusChange(context, 'cancel'),
                ),
                const SizedBox(height: 16),
              ],

              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child:
                    isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.cream,
                          ),
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

  void _confirmStatusChange(BuildContext context, String action) {
    final isCancel = action == 'cancel';
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppColors.cream,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.green,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(editProjectProvider.notifier)
                      .changeStatus(
                        projectId: widget.project.id,
                        status: isCancel ? 'Cancelled' : 'paised',
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isCancel ? ' Project cancelled' : ' Project paused',
                      ),
                      backgroundColor: AppColors.forest,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCancel ? AppColors.error : AppColors.gold,
                  foregroundColor: Colors.white,
                ),
                child: Text(isCancel ? 'Yes, cancel' : 'Pause'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTextStyles.label.copyWith(
      color: AppColors.forest,
      letterSpacing: 0.8,
    ),
  );
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
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected
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
  Widget build(BuildContext context) => Container(
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
          activeColor: AppColors.forest,
        ),
      ],
    ),
  );
}

class _DangerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _DangerAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.mediumImpact();
      onTap();
    },
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: color.withValues(alpha: 0.5),
            size: 18,
          ),
        ],
      ),
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
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
