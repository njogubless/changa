import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';

import 'package:changa/features/projects/presentation/widgets/project_form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  final String chamaId;
  const CreateProjectScreen({super.key, required this.chamaId});

  @override
  ConsumerState<CreateProjectScreen> createState() =>
      _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _paymentNumberCtrl = TextEditingController();
  final _paymentNameCtrl = TextEditingController();
  final _accountRefCtrl = TextEditingController();
  String _paymentType = 'till';
  bool _isAnonymous = false;
  DateTime? _deadline;
  String? _errorMessage;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _paymentNumberCtrl.dispose();
    _paymentNameCtrl.dispose();
    _accountRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    await ref.read(createChamaProjectProvider.notifier).create(
          chamaId: widget.chamaId,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty
              ? _descCtrl.text.trim()
              : null,
          targetAmount:
              double.parse(_amountCtrl.text.replaceAll(',', '')),
          paymentType: _paymentType,
          paymentNumber: _paymentNumberCtrl.text.trim(),
          paymentName: _paymentNameCtrl.text.trim().isNotEmpty
              ? _paymentNameCtrl.text.trim()
              : null,
          accountReference: _paymentType == 'paybill' &&
                  _accountRefCtrl.text.trim().isNotEmpty
              ? _accountRefCtrl.text.trim()
              : null,
          isAnonymous: _isAnonymous,
          deadline: _deadline,
        );

    if (!mounted) return;

    final state = ref.read(createChamaProjectProvider);
    if (state.created != null) {
      ref.read(chamaProjectsProvider(widget.chamaId).notifier).refresh();
      ref.read(createChamaProjectProvider.notifier).reset();
      context.pushReplacement(
          '/projects/${state.created!.id}');
    } else if (state.error != null) {
      setState(() => _errorMessage = _friendlyError(state.error!));
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('100')) return 'Target must be at least KES 100.';
    if (raw.contains('Network')) return 'No internet connection.';
    if (raw.contains('403')) return 'Only the Chama owner can create projects.';
    return 'Could not create project. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createChamaProjectProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.cream,
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
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              const SizedBox(height: 24),

             
              const ProjectSectionLabel('Payment account'),
              const SizedBox(height: 4),
              Text(
                'Where contributors will send money',
                style: AppTextStyles.caption.copyWith(color: AppColors.green),
              ),
              const SizedBox(height: 12),

              
              Row(
                children: [
                  _PaymentTypeChip(
                    label: 'Till',
                    selected: _paymentType == 'till',
                    onTap: () => setState(() => _paymentType = 'till'),
                  ),
                  const SizedBox(width: 8),
                  _PaymentTypeChip(
                    label: 'Paybill',
                    selected: _paymentType == 'paybill',
                    onTap: () => setState(() => _paymentType = 'paybill'),
                  ),
                  const SizedBox(width: 8),
                  _PaymentTypeChip(
                    label: 'Pochi',
                    selected: _paymentType == 'pochi',
                    onTap: () => setState(() => _paymentType = 'pochi'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

             
              TextFormField(
                controller: _paymentNumberCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: _paymentType == 'pochi'
                      ? '254712345678'
                      : _paymentType == 'paybill'
                          ? 'Business number e.g. 522522'
                          : 'Till number e.g. 123456',
                  prefixIcon: Icon(
                    _paymentType == 'pochi'
                        ? Icons.phone_android
                        : Icons.account_balance_outlined,
                    color: AppColors.mpesaGreen,
                    size: 20,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Payment number is required';
                  }
                  if (v.trim().length < 5) {
                    return 'Payment number is too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              
              TextFormField(
                controller: _paymentNameCtrl,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Account name e.g. NAIROBI YOUTH GROUP',
                  prefixIcon: Icon(Icons.verified_outlined,
                      color: AppColors.green, size: 20),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This name will be shown to contributors before they pay',
                style: AppTextStyles.caption.copyWith(color: AppColors.green),
              ),

             
              if (_paymentType == 'paybill') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountRefCtrl,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: 'Account number / reference',
                    prefixIcon: Icon(Icons.tag_outlined,
                        color: AppColors.green, size: 20),
                  ),
                ),
              ],
              const SizedBox(height: 24),

             
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
                  final picked = await pickProjectDeadline(context,
                      initial: _deadline);
                  if (picked != null) setState(() => _deadline = picked);
                },
                onClear: () => setState(() => _deadline = null),
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
                    : const Text('Create project'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.forest
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.sand,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: selected ? AppColors.cream : AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}