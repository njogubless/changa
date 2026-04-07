import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:changa/features/budget/presentation/providers/budget_provider.dart';
import 'package:changa/features/chama/data/models/chama_model.dart';
import 'package:changa/features/chama/presentation/providers/chama_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

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

  // Line items being built
  final List<_LineItemDraft> _lineItems = [];

  // Chama linking
  bool _linkToChama = false;
  ChamaModel? _selectedChama;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  double get _totalAllocated =>
      _lineItems.fold(0, (s, i) => s + (i.amount ?? 0));
  double get _totalIncome =>
      double.tryParse(_incomeCtrl.text.replaceAll(',', '')) ?? 0;
  double get _unallocated => _totalIncome - _totalAllocated;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lineItems.isEmpty) {
      setState(() => _errorMessage = 'Add at least one budget category.');
      return;
    }
    setState(() => _errorMessage = null);

    final lineItems = _lineItems.map((d) => BudgetLineItem(
          id: _uuid.v4(),
          category: d.category,
          customLabel: d.customLabel,
          allocatedAmount: d.amount!,
        )).toList();

    await ref.read(createBudgetProvider.notifier).create(
          title: _titleCtrl.text.trim(),
          type: _type,
          totalIncome: _totalIncome,
          lineItems: lineItems,
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
              if (_errorMessage != null) ...[
                _ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 16),
              ],

              // ── Title ──────────────────────────────────────────────
              _Label('Budget name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'e.g. June Budget, Wedding, Chama Savings',
                ),
                validator: (v) => v == null || v.trim().length < 3
                    ? 'Name must be at least 3 characters'
                    : null,
              ),
              const SizedBox(height: 20),

              // ── Type ───────────────────────────────────────────────
              _Label('Budget type'),
              const SizedBox(height: 10),
              Row(
                children: BudgetType.values.map((t) {
                  final selected = _type == t;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: t != BudgetType.values.last ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _type = t;
                          if (t != BudgetType.chamaContribution) {
                            _linkToChama = false;
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.forest.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? AppColors.forest
                                  : AppColors.sand,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(t.icon,
                                  size: 20,
                                  color: selected
                                      ? AppColors.forest
                                      : AppColors.sand),
                              const SizedBox(height: 6),
                              Text(
                                t.label,
                                style: AppTextStyles.caption.copyWith(
                                  color: selected
                                      ? AppColors.forest
                                      : AppColors.green,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
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
              ),
              const SizedBox(height: 20),

              // ── Event date (event type only) ───────────────────────
              if (_type == BudgetType.event) ...[
                _Label('Event date (optional)'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 3)),
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
                    if (picked != null) setState(() => _eventDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 18,
                            color: _eventDate != null
                                ? AppColors.forest
                                : AppColors.sand),
                        const SizedBox(width: 10),
                        Text(
                          _eventDate != null
                              ? '${_eventDate!.day} ${_monthName(_eventDate!.month)} ${_eventDate!.year}'
                              : 'No date set',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _eventDate != null
                                ? AppColors.forest
                                : Colors.grey.shade400,
                          ),
                        ),
                        const Spacer(),
                        if (_eventDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _eventDate = null),
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.sand),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Link to Chama ──────────────────────────────────────
              if (chamaState.chamas.isNotEmpty) ...[
                Container(
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
                                Text(
                                  'Link to a Chama',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.forest,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Track contributions for a specific Chama',
                                  style: AppTextStyles.caption
                                      .copyWith(color: AppColors.green),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _linkToChama,
                            onChanged: (v) =>
                                setState(() => _linkToChama = v),
                            activeThumbColor: AppColors.forest,
                          ),
                        ],
                      ),
                      if (_linkToChama) ...[
                        const SizedBox(height: 12),
                        ...chamaState.chamas.map((chama) {
                          final selected = _selectedChama?.id == chama.id;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedChama = chama),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.forest.withValues(alpha: 0.08)
                                    : AppColors.cream,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.forest
                                      : AppColors.sand,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 16, color: AppColors.forest),
                                  const SizedBox(width: 8),
                                  Text(
                                    chama.name,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.forest,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  if (selected) ...[
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
                ),
                const SizedBox(height: 20),
              ],

              // ── Total income ───────────────────────────────────────
              _Label('Total income / budget (KES)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _incomeCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'e.g. 50000',
                  prefixText: 'KES ',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final amount = double.tryParse(v?.replaceAll(',', '') ?? '');
                  if (amount == null || amount < 1) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Line items ─────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _Label('Budget categories'),
                  ),
                  TextButton.icon(
                    onPressed: _addLineItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.forest),
                  ),
                ],
              ),

              // Unallocated indicator
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sand),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.sand, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Tap "Add" to add expense categories',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.green),
                      ),
                    ],
                  ),
                )
              else
                ..._lineItems.asMap().entries.map((e) {
                  final idx = e.key;
                  final item = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LineItemRow(
                      item: item,
                      budgetType: _type,
                      onChanged: (updated) => setState(
                          () => _lineItems[idx] = updated),
                      onRemove: () =>
                          setState(() => _lineItems.removeAt(idx)),
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
      _lineItems.add(_LineItemDraft(
        category: _defaultCategories(_type).first,
      ));
    });
  }

  List<BudgetCategory> _defaultCategories(BudgetType type) {
    switch (type) {
      case BudgetType.personal:
        return [
          BudgetCategory.food,
          BudgetCategory.transport,
          BudgetCategory.rent,
          BudgetCategory.utilities,
          BudgetCategory.healthcare,
          BudgetCategory.education,
          BudgetCategory.entertainment,
          BudgetCategory.clothing,
          BudgetCategory.savings,
          BudgetCategory.other,
        ];
      case BudgetType.event:
        return [
          BudgetCategory.venue,
          BudgetCategory.catering,
          BudgetCategory.decoration,
          BudgetCategory.photography,
          BudgetCategory.music,
          BudgetCategory.transport_event,
          BudgetCategory.gifts,
          BudgetCategory.other,
        ];
      case BudgetType.chamaContribution:
        return [
          BudgetCategory.contribution,
          BudgetCategory.other,
        ];
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

// ── Line item draft ────────────────────────────────────────────────────────

class _LineItemDraft {
  BudgetCategory category;
  double? amount;
  String? customLabel;

  _LineItemDraft({required this.category, this.amount, this.customLabel});

  _LineItemDraft copyWith({
    BudgetCategory? category,
    double? amount,
    String? customLabel,
  }) =>
      _LineItemDraft(
        category: category ?? this.category,
        amount: amount ?? this.amount,
        customLabel: customLabel ?? this.customLabel,
      );
}

// ── Line item row ──────────────────────────────────────────────────────────

class _LineItemRow extends StatefulWidget {
  final _LineItemDraft item;
  final BudgetType budgetType;
  final ValueChanged<_LineItemDraft> onChanged;
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

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.item.amount?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  List<BudgetCategory> get _categories {
    switch (widget.budgetType) {
      case BudgetType.personal:
        return [
          BudgetCategory.food, BudgetCategory.transport, BudgetCategory.rent,
          BudgetCategory.utilities, BudgetCategory.healthcare,
          BudgetCategory.education, BudgetCategory.entertainment,
          BudgetCategory.clothing, BudgetCategory.savings, BudgetCategory.other,
        ];
      case BudgetType.event:
        return [
          BudgetCategory.venue, BudgetCategory.catering,
          BudgetCategory.decoration, BudgetCategory.photography,
          BudgetCategory.music, BudgetCategory.transport_event,
          BudgetCategory.gifts, BudgetCategory.other,
        ];
      case BudgetType.chamaContribution:
        return [BudgetCategory.contribution, BudgetCategory.other];
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sand),
        ),
        child: Row(
          children: [
            // Category icon
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
            // Category dropdown
            Expanded(
              flex: 3,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BudgetCategory>(
                  value: widget.item.category,
                  isDense: true,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.forest,
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.label),
                          ))
                      .toList(),
                  onChanged: (c) {
                    if (c != null) {
                      widget.onChanged(widget.item.copyWith(category: c));
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Amount input
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.forest),
                decoration: InputDecoration(
                  hintText: 'Amount',
                  hintStyle: AppTextStyles.caption
                      .copyWith(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.sand),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.sand),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.forest),
                  ),
                ),
                onChanged: (v) {
                  final amount = double.tryParse(v);
                  widget.onChanged(widget.item.copyWith(amount: amount));
                },
              ),
            ),
            const SizedBox(width: 6),
            // Remove
            GestureDetector(
              onTap: widget.onRemove,
              child: const Icon(Icons.remove_circle_outline,
                  color: AppColors.error, size: 20),
            ),
          ],
        ),
      );
}

// ── Allocation bar ─────────────────────────────────────────────────────────

class _AllocationBar extends StatelessWidget {
  final double allocated;
  final double total;
  final double unallocated;
  const _AllocationBar({
    required this.allocated,
    required this.total,
    required this.unallocated,
  });

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
              isOver ? AppColors.error : AppColors.sage,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isOver
              ? 'Over budget by KES ${(allocated - total).toStringAsFixed(0)}'
              : 'KES ${unallocated.toStringAsFixed(0)} unallocated',
          style: AppTextStyles.caption.copyWith(
            color: isOver ? AppColors.error : AppColors.green,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

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
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
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