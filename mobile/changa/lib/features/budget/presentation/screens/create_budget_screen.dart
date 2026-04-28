import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:changa/features/budget/presentation/providers/budget_provider.dart';
import 'package:changa/features/budget/presentation/widgets/budget_widgets.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class LineItemDraft {
  final BudgetCategory category;
  final double? amount;
  final String? customLabel;

  const LineItemDraft({
    required this.category,
    this.amount,
    this.customLabel,
  });

  LineItemDraft copyWith({
    BudgetCategory? category,
    double? amount,
    String? customLabel,
    bool clearCustomLabel = false,
  }) =>
      LineItemDraft(
        category: category ?? this.category,
        amount: amount ?? this.amount,
        customLabel:
            clearCustomLabel ? null : (customLabel ?? this.customLabel),
      );

  BudgetLineItem toLineItem() => BudgetLineItem(
        id: _uuid.v4(),
        category: category,
        customLabel: customLabel,
        allocatedAmount: amount!,
      );
}


class CreateBudgetScreen extends ConsumerStatefulWidget {
  const CreateBudgetScreen({super.key});

  @override
  ConsumerState<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends ConsumerState<CreateBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();

  BudgetType _type = BudgetType.personal;
  DateTime? _eventDate;
  String? _errorMessage;
  final List<LineItemDraft> _lineItems = [];
  bool _linkToChama = false;
  ChamaModel? _selectedChama;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  double get _totalIncome =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
  double get _totalAllocated =>
      _lineItems.fold(0, (s, i) => s + (i.amount ?? 0));
  double get _unallocated => _totalIncome - _totalAllocated;

  String? _validate() {
    if (!_formKey.currentState!.validate()) return '';
    if (_lineItems.isEmpty) return 'Add at least one budget category.';
    if (_lineItems.any((i) => i.amount == null || i.amount! <= 0)) {
      return 'All categories need an amount greater than 0.';
    }
    if (_lineItems.any(
        (i) => i.category == BudgetCategory.other &&
            (i.customLabel == null || i.customLabel!.trim().isEmpty))) {
      return 'Give a name to your "Other" categories.';
    }
    if (_linkToChama && _selectedChama == null) {
      return 'Select a Chama to link, or turn off the toggle.';
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _errorMessage = error.isEmpty ? null : error);
      return;
    }
    setState(() => _errorMessage = null);

    await ref.read(createBudgetProvider.notifier).create(
          title: _titleCtrl.text.trim(),
          type: _type,
          totalIncome: _totalIncome,
          lineItems: _lineItems.map((d) => d.toLineItem()).toList(),
          eventDate: _eventDate,
          linkedChamaId: _linkToChama ? _selectedChama?.id : null,
          linkedChamaName: _linkToChama ? _selectedChama?.name : null,
        );

    if (!mounted) return;
    final state = ref.read(createBudgetProvider);
    if (state.created != null) {
      ref.read(budgetListProvider.notifier).refresh();
      ref.read(createBudgetProvider.notifier).reset();
      context.pushReplacement('/budget/${state.created!.id}');
    } else if (state.error != null) {
      setState(() => _errorMessage = 'Could not create budget. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(createBudgetProvider).isLoading;
    final chamaState = ref.watch(chamaListProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('New Budget'),
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
              if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                BudgetErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

              const BudgetSectionLabel('Budget name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest),
                decoration: const InputDecoration(
                  hintText: 'e.g. June Budget, Wedding, Chama Savings',
                ),
                validator: (v) => v == null || v.trim().length < 3
                    ? 'Name must be at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 20),

              const BudgetSectionLabel('Budget type'),
              const SizedBox(height: 10),
              _TypeSelector(
                selected: _type,
                onChanged: (t) => setState(() {
                  _type = t;
                  _lineItems.clear();
                  if (t != BudgetType.chamaContribution) _linkToChama = false;
                }),
              ),
              const SizedBox(height: 20),

              if (_type == BudgetType.event) ...[
                const BudgetSectionLabel('Event date (optional)'),
                const SizedBox(height: 8),
                _DatePicker(
                  date: _eventDate,
                  onPicked: (d) => setState(() => _eventDate = d),
                  onCleared: () => setState(() => _eventDate = null),
                ),
                const SizedBox(height: 20),
              ],

              if (chamaState.chamas.isNotEmpty) ...[
                _ChamaLinker(
                  chamas: chamaState.chamas,
                  isLinked: _linkToChama,
                  selected: _selectedChama,
                  onToggle: (v) => setState(() => _linkToChama = v),
                  onSelect: (c) => setState(() => _selectedChama = c),
                ),
                const SizedBox(height: 20),
              ],

              const BudgetSectionLabel('Total income / budget (KES)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _incomeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.forest),
                decoration: const InputDecoration(
                  hintText: 'e.g. 50000',
                  prefixText: 'KES ',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final amount = double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (amount == null || amount < 1) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Expanded(child: BudgetSectionLabel('Budget categories')),
                  TextButton.icon(
                    onPressed: _addLineItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.forest),
                  ),
                ],
              ),

              if (_incomeCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 4),
                _AllocationBar(
                  allocated: _totalAllocated,
                  total: _totalIncome,
                  unallocated: _unallocated,
                ),
              ],
              const SizedBox(height: 12),

              if (_lineItems.isEmpty)
                _EmptyCategories()
              else
                ..._lineItems.asMap().entries.map((e) {
                  final idx = e.key;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LineItemRow(
                      item: _lineItems[idx],
                      budgetType: _type,
                      onChanged: (updated) =>
                          setState(() => _lineItems[idx] = updated),
                      onRemove: () => setState(() => _lineItems.removeAt(idx)),
                    ),
                  );
                }),

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
                    : const Text('Create Budget'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(LineItemDraft(category: categoriesFor(_type).first));
    });
  }
}



class _TypeSelector extends StatelessWidget {
  final BudgetType selected;
  final ValueChanged<BudgetType> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        children: BudgetType.values.map((t) {
          final isSelected = selected == t;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: t != BudgetType.values.last ? 8 : 0),
              child: GestureDetector(
                onTap: () => onChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.forest.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.forest : AppColors.sand,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(t.icon,
                          size: 20,
                          color: isSelected ? AppColors.forest : AppColors.sand),
                      const SizedBox(height: 6),
                      Text(
                        t.label,
                        style: AppTextStyles.caption.copyWith(
                          color: isSelected ? AppColors.forest : AppColors.green,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
}



class _DatePicker extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onCleared;
  const _DatePicker(
      {required this.date,
      required this.onPicked,
      required this.onCleared});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now().add(const Duration(days: 30)),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
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
          if (picked != null) onPicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sand),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 18,
                  color: date != null ? AppColors.forest : AppColors.sand),
              const SizedBox(width: 10),
              Text(
                date != null
                    ? DateFormat('d MMM yyyy').format(date!)
                    : 'No date set',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: date != null ? AppColors.forest : Colors.grey.shade400,
                ),
              ),
              const Spacer(),
              if (date != null)
                GestureDetector(
                  onTap: onCleared,
                  child: const Icon(Icons.close, size: 16, color: AppColors.sand),
                ),
            ],
          ),
        ),
      );
}



class _ChamaLinker extends StatelessWidget {
  final List<ChamaModel> chamas;
  final bool isLinked;
  final ChamaModel? selected;
  final ValueChanged<bool> onToggle;
  final ValueChanged<ChamaModel> onSelect;

  const _ChamaLinker({
    required this.chamas,
    required this.isLinked,
    required this.selected,
    required this.onToggle,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sand),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Link to a Chama',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.forest,
                              fontWeight: FontWeight.w600)),
                      Text('Track contributions for a specific Chama',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.green)),
                    ],
                  ),
                ),
                Switch(
                    value: isLinked,
                    onChanged: onToggle,
                    activeThumbColor: AppColors.forest),
              ],
            ),
            if (isLinked) ...[
              const SizedBox(height: 12),
              ...chamas.map((chama) {
                final isSelected = selected?.id == chama.id;
                return GestureDetector(
                  onTap: () => onSelect(chama),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.forest.withValues(alpha: 0.08)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.forest
                              : AppColors.sand),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline,
                            size: 16, color: AppColors.forest),
                        const SizedBox(width: 8),
                        Text(chama.name,
                            style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.forest,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w400)),
                        if (isSelected) ...[
                          const Spacer(),
                          const Icon(Icons.check_circle,
                              size: 16, color: AppColors.forest),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      );
}



class _AllocationBar extends StatelessWidget {
  final double allocated;
  final double total;
  final double unallocated;
  const _AllocationBar(
      {required this.allocated,
      required this.total,
      required this.unallocated});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (allocated / total).clamp(0.0, 1.0) : 0.0;
    final isOver = allocated > total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.sand.withValues(alpha: 0.4),
            valueColor: AlwaysStoppedAnimation(
                isOver ? AppColors.error : AppColors.sage),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isOver
              ? 'Over budget by KES ${(allocated - total).toStringAsFixed(0)}'
              : 'KES ${unallocated.toStringAsFixed(0)} unallocated',
          style: AppTextStyles.caption
              .copyWith(color: isOver ? AppColors.error : AppColors.green),
        ),
      ],
    );
  }
}



class _EmptyCategories extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sand),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.sand, size: 18),
            const SizedBox(width: 10),
            Text('Tap "Add" to add expense categories',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.green)),
          ],
        ),
      );
}


class _LineItemRow extends StatefulWidget {
  final LineItemDraft item;
  final BudgetType budgetType;
  final ValueChanged<LineItemDraft> onChanged;
  final VoidCallback onRemove;

  const _LineItemRow({
    required this.item,
    required this.budgetType,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_LineItemRow> createState() => _LineItemRowState();
}

class _LineItemRowState extends State<_LineItemRow> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _customLabelCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.item.amount?.toStringAsFixed(0) ?? '');
    _customLabelCtrl =
        TextEditingController(text: widget.item.customLabel ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _customLabelCtrl.dispose();
    super.dispose();
  }

  bool get _isCustom => widget.item.category == BudgetCategory.other;

  @override
  Widget build(BuildContext context) {
    final categories = categoriesFor(widget.budgetType);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sand),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.item.category.icon,
                    size: 18, color: AppColors.forest),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CategoryDropdown(
                  value: widget.item.category,
                  categories: categories,
                  onChanged: (c) {
                    if (c != null) {
                      widget.onChanged(widget.item.copyWith(
                          category: c, clearCustomLabel: true));
                      if (c != BudgetCategory.other) _customLabelCtrl.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onRemove,
                child: const Icon(Icons.remove_circle_outline,
                    color: AppColors.error, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 10),

          
          Row(
            children: [
              Expanded(
                flex: _isCustom ? 2 : 3,
                child: _StyledField(
                  controller: _amountCtrl,
                  hint: 'Amount',
                  prefix: 'KES ',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => widget.onChanged(
                      widget.item.copyWith(amount: double.tryParse(v))),
                ),
              ),
              if (_isCustom) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _StyledField(
                    controller: _customLabelCtrl,
                    hint: 'e.g. School fees',
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (v) => widget.onChanged(
                        widget.item.copyWith(customLabel: v.trim())),
                  ),
                ),
              ],
            ],
          ),

          if (_isCustom) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.edit_outlined, size: 11, color: AppColors.sand),
                const SizedBox(width: 4),
                Text(
                  'Enter a custom name for this category',
                  style: AppTextStyles.caption.copyWith(color: AppColors.sand),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}



class _CategoryDropdown extends StatelessWidget {
  final BudgetCategory value;
  final List<BudgetCategory> categories;
  final ValueChanged<BudgetCategory?> onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.sand),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<BudgetCategory>(
            value: value,
            isExpanded: true,
            isDense: true,
            icon: const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.forest),
            dropdownColor: AppColors.cream,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.forest,
              fontWeight: FontWeight.w500,
            ),
            items: categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(c.icon, size: 14, color: AppColors.forest),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            c.label,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.forest),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
}



class _StyledField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  const _StyledField({
    required this.controller,
    required this.hint,
    this.prefix,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textCapitalization: textCapitalization,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.forest,
          fontWeight: FontWeight.w500,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixText: prefix,
          prefixStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
          hintStyle: AppTextStyles.caption.copyWith(color: AppColors.sand),
          filled: true,
          fillColor: AppColors.cream,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.sand),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.sand),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
          ),
        ),
      );
}