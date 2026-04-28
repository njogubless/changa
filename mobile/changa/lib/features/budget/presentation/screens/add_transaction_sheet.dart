import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

typedef OnTransactionSubmit = Future<void> Function({
  required String lineItemId,
  required TransactionType type,
  required double amount,
  required String description,
  DateTime? date,
});

class AddTransactionSheet extends StatefulWidget {
  final BudgetModel budget;
  final BudgetLineItem? preselectedLineItem;
  final OnTransactionSubmit onSubmit;

  const AddTransactionSheet({
    super.key,
    required this.budget,
    required this.onSubmit,
    this.preselectedLineItem,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late BudgetLineItem _selectedItem;
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.preselectedLineItem ?? widget.budget.lineItems.first;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        lineItemId: _selectedItem.id,
        type: _type,
        amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
        description: _descCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not save transaction. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Add Transaction',
                style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
            const SizedBox(height: 20),

            
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Text(_error!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.error)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            
            _FieldLabel('Type'),
            const SizedBox(height: 8),
            Row(
              children: TransactionType.values.map((t) {
                final isExpense = t == TransactionType.expense;
                final selected = _type == t;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: t == TransactionType.expense ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? (isExpense
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : AppColors.sage.withValues(alpha: 0.15))
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? (isExpense ? AppColors.error : AppColors.sage)
                                : AppColors.sand,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isExpense
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 16,
                              color: selected
                                  ? (isExpense ? AppColors.error : AppColors.sage)
                                  : AppColors.sand,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isExpense ? 'Expense' : 'Income',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: selected
                                    ? (isExpense
                                        ? AppColors.error
                                        : AppColors.sage)
                                    : AppColors.green,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            
            _FieldLabel('Category'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sand),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<BudgetLineItem>(
                  value: _selectedItem,
                  isExpanded: true,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.forest),
                  items: widget.budget.lineItems
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Row(
                            children: [
                              Icon(item.category.icon,
                                  size: 16, color: AppColors.forest),
                              const SizedBox(width: 8),
                              Text(item.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (item) {
                    if (item != null) setState(() => _selectedItem = item);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            
            _FieldLabel('Amount (KES)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'e.g. 1500',
                prefixText: 'KES ',
              ),
              validator: (v) {
                final amount =
                    double.tryParse(v?.replaceAll(',', '') ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            
            _FieldLabel('Description'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.bodyMedium,
              decoration: const InputDecoration(
                hintText: 'e.g. Naivas groceries',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Add a description'
                  : null,
            ),
            const SizedBox(height: 16),

            
            _FieldLabel('Date'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
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
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sand),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.forest),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('d MMM yyyy').format(_date),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.forest),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.cream),
                    )
                  : const Text('Save Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: AppColors.forest,
          letterSpacing: 0.8,
        ),
      );
}