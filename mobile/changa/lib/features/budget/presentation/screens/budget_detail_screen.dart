import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:changa/features/budget/presentation/providers/budget_provider.dart';
import 'package:changa/features/budget/presentation/screens/add_transaction_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final _fmt = NumberFormat('#,##0', 'en_KE');
String _kes(double v) => 'KES ${_fmt.format(v)}';

class BudgetDetailScreen extends ConsumerWidget {
  final String budgetId;
  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetDetailProvider(budgetId));

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.forest, strokeWidth: 2),
        ),
      );
    }

    if (state.error != null || state.budget == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.sand, size: 48),
              const SizedBox(height: 16),
              Text('Could not load budget',
                  style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(budgetDetailProvider(budgetId).notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final budget = state.budget!;
    final sortedTx = [...budget.transactions]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: AppColors.forest,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.cream),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.cream),
                onPressed: () => _confirmDelete(context, ref, budget),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _DetailHeader(budget: budget),
            ),
          ),

          // ── Overview cards ──────────────────────────────────────
          SliverToBoxAdapter(child: _OverviewSection(budget: budget)),

          // ── Categories ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeading(
              title: 'CATEGORIES',
              trailing: TextButton.icon(
                onPressed: () => _openAddTransaction(context, ref, budget, null),
                icon: const Icon(Icons.add, size: 16, color: AppColors.forest),
                label: Text(
                  'Add Transaction',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LineItemCard(
                    item: budget.lineItems[i],
                    onAddTransaction: () => _openAddTransaction(
                        context, ref, budget, budget.lineItems[i]),
                  ),
                ),
                childCount: budget.lineItems.length,
              ),
            ),
          ),

          // ── Transactions ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeading(title: 'TRANSACTIONS'),
          ),

          if (sortedTx.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyTransactions(
                onAdd: () => _openAddTransaction(context, ref, budget, null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TransactionTile(
                    tx: sortedTx[i],
                    budget: budget,
                    onDelete: () => ref
                        .read(budgetDetailProvider(budgetId).notifier)
                        .deleteTransaction(sortedTx[i].id),
                  ),
                  childCount: sortedTx.length,
                ),
              ),
            ),
        ],
      ),

      // ── FAB ─────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransaction(context, ref, budget, null),
        backgroundColor: AppColors.forest,
        icon: const Icon(Icons.add, color: AppColors.cream),
        label: Text(
          'Add Transaction',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.cream,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _openAddTransaction(
    BuildContext context,
    WidgetRef ref,
    BudgetModel budget,
    BudgetLineItem? preselected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        budget: budget,
        preselectedLineItem: preselected,
        onSubmit: ({
          required lineItemId,
          required type,
          required amount,
          required description,
          date,
        }) async {
          await ref
              .read(budgetDetailProvider(budgetId).notifier)
              .addTransaction(
                lineItemId: lineItemId,
                type: type,
                amount: amount,
                description: description,
                date: date,
              );
          ref.read(budgetListProvider.notifier).refresh();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, BudgetModel budget) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 20),
              Text('Delete budget?',
                  style: AppTextStyles.h3.copyWith(color: AppColors.forest)),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete "${budget.title}" and all its transactions.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(budgetListProvider.notifier)
                      .deleteBudget(budget.id);
                  if (context.mounted) context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Delete'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail header ───────────────────────────────────────────────────────────

class _DetailHeader extends StatelessWidget {
  final BudgetModel budget;
  const _DetailHeader({required this.budget});

  @override
  Widget build(BuildContext context) {
    final progress = budget.overallProgress;
    final isOver = budget.totalSpent > budget.totalAllocated;

    return Container(
      color: AppColors.forest,
      padding: const EdgeInsets.fromLTRB(20, 88, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(budget.type.icon, color: AppColors.mint, size: 14),
              const SizedBox(width: 6),
              Text(
                budget.type.label.toUpperCase(),
                style: AppTextStyles.caption.copyWith(color: AppColors.mint),
              ),
              if (budget.isLinkedToChama) ...[
                const SizedBox(width: 10),
                const Icon(Icons.people_outline, color: AppColors.mint, size: 14),
                const SizedBox(width: 4),
                Text(
                  budget.linkedChamaName ?? '',
                  style: AppTextStyles.caption.copyWith(color: AppColors.mint),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            budget.title,
            style: AppTextStyles.h2.copyWith(color: AppColors.cream, height: 1.2),
          ),
          if (budget.eventDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 12, color: AppColors.mint),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM yyyy').format(budget.eventDate!),
                  style: AppTextStyles.caption.copyWith(color: AppColors.mint),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.cream.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                isOver ? AppColors.error : AppColors.mint,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% spent',
                style: AppTextStyles.caption.copyWith(color: AppColors.mint),
              ),
              Text(
                _kes(budget.totalIncome),
                style: AppTextStyles.caption.copyWith(color: AppColors.mint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Overview section ────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  final BudgetModel budget;
  const _OverviewSection({required this.budget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Allocated',
              value: _kes(budget.totalAllocated),
              icon: Icons.pie_chart_outline,
              iconColor: AppColors.sage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Spent',
              value: _kes(budget.totalSpent),
              icon: Icons.arrow_upward_rounded,
              iconColor: AppColors.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Remaining',
              value: _kes(budget.remaining),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: AppColors.green)),
          ],
        ),
      );
}

// ── Section heading ─────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeading({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.forest,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

// ── Line item card ──────────────────────────────────────────────────────────

class _LineItemCard extends StatelessWidget {
  final BudgetLineItem item;
  final VoidCallback onAddTransaction;
  const _LineItemCard({required this.item, required this.onAddTransaction});

  @override
  Widget build(BuildContext context) {
    final isOver = item.isOverBudget;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                child: Icon(item.category.icon,
                    size: 18, color: AppColors.forest),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_kes(item.spentAmount)} of ${_kes(item.allocatedAmount)}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.green),
                    ),
                  ],
                ),
              ),
              // Quick add button
              GestureDetector(
                onTap: onAddTransaction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 14, color: AppColors.forest),
                      const SizedBox(width: 2),
                      Text(
                        'Add',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.progress,
              minHeight: 5,
              backgroundColor: AppColors.sand.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(
                isOver ? AppColors.error : AppColors.forest,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOver
                    ? 'Over by ${_kes(item.spentAmount - item.allocatedAmount)}'
                    : '${_kes(item.remaining)} remaining',
                style: AppTextStyles.caption.copyWith(
                  color: isOver ? AppColors.error : AppColors.green,
                ),
              ),
              Text(
                '${(item.progress * 100).toStringAsFixed(0)}%',
                style: AppTextStyles.caption.copyWith(
                  color: isOver ? AppColors.error : AppColors.forest,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile ────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final BudgetTransaction tx;
  final BudgetModel budget;
  final VoidCallback onDelete;
  const _TransactionTile({
    required this.tx,
    required this.budget,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = tx.type == TransactionType.expense;
    final lineItem = budget.lineItems
        .where((i) => i.id == tx.lineItemId)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Type indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isExpense
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.sage.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 16,
              color: isExpense ? AppColors.error : AppColors.sage,
            ),
          ),
          const SizedBox(width: 10),
          // Description + category
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.forest,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${lineItem?.label ?? 'Unknown'} · ${DateFormat('d MMM, HH:mm').format(tx.date)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : '+'}${_kes(tx.amount)}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isExpense ? AppColors.error : AppColors.sage,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: const Icon(Icons.close, size: 14, color: AppColors.sand),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete transaction?',
            style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
        content: Text(
          'Remove "${tx.description}" — ${_kes(tx.amount)}?',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.green),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: Text('Delete',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── Empty transactions ──────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTransactions({required this.onAdd});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.sand.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  color: AppColors.sand, size: 28),
            ),
            const SizedBox(height: 16),
            Text('No transactions yet',
                style: AppTextStyles.h4.copyWith(color: AppColors.forest)),
            const SizedBox(height: 6),
            Text(
              'Tap "Add Transaction" to record\nyour first expense or income.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.green, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Transaction'),
              ),
            ),
          ],
        ),
      );
}