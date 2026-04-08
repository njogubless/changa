import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:changa/features/budget/presentation/providers/budget_provider.dart';
import 'package:changa/features/budget/presentation/widgets/budget_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetListProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => ref.read(budgetListProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 130,
              floating: true,
              snap: true,
              pinned: false,
              backgroundColor: AppColors.forest,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: AppColors.forest,
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'My Budgets',
                        style: AppTextStyles.h2
                            .copyWith(color: AppColors.cream, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track every shilling',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.mint),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Summary cards ───────────────────────────────────────
            if (state.budgets.isNotEmpty)
              SliverToBoxAdapter(
                child: _SummaryRow(budgets: state.budgets),
              ),

            // ── Create button ───────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: GestureDetector(
                  onTap: () => context.push('/budget/create'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.forest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline,
                            color: AppColors.cream, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Create Budget',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Body states ─────────────────────────────────────────
            if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.forest, strokeWidth: 2),
                ),
              )
            else if (state.error != null)
              SliverFillRemaining(
                child: BudgetErrorState(
                  message: 'Could not load budgets',
                  onRetry: () =>
                      ref.read(budgetListProvider.notifier).refresh(),
                ),
              )
            else if (state.budgets.isEmpty)
              const SliverFillRemaining(
                child: BudgetEmptyState(
                  title: 'No budgets yet',
                  subtitle: 'Create a budget to start tracking\nyour spending.',
                  icon: Icons.bar_chart_outlined,
                  iconColor: AppColors.gold,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BudgetCard(
                        budget: state.budgets[i],
                        onDelete: () => ref
                            .read(budgetListProvider.notifier)
                            .deleteBudget(state.budgets[i].id),
                      ),
                    ),
                    childCount: state.budgets.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Summary row ─────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final List<BudgetModel> budgets;
  const _SummaryRow({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final totalIncome = budgets.fold(0.0, (s, b) => s + b.totalIncome);
    final totalSpent = budgets.fold(0.0, (s, b) => s + b.totalSpent);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: BudgetStatCard(
              label: 'Total Income',
              value: kesFormat(totalIncome),
              icon: Icons.arrow_downward_rounded,
              iconColor: AppColors.sage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BudgetStatCard(
              label: 'Total Spent',
              value: kesFormat(totalSpent),
              icon: Icons.arrow_upward_rounded,
              iconColor: AppColors.error,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BudgetStatCard(
              label: 'Remaining',
              value: kesFormat(totalIncome - totalSpent),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget card ──────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final VoidCallback onDelete;
  const _BudgetCard({required this.budget, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isOver = budget.totalSpent > budget.totalAllocated;

    return GestureDetector(
      onTap: () => context.push('/budget/${budget.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Row(
              children: [
                // Type icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(budget.type.icon,
                      color: AppColors.forest, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.forest,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // Type + chama chips inline
                      Row(
                        children: [
                          Text(
                            budget.type.label,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.green),
                          ),
                          if (budget.isLinkedToChama) ...[
                            Text(
                              ' · ',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.sand),
                            ),
                            const Icon(Icons.people_outline,
                                size: 10, color: AppColors.green),
                            const SizedBox(width: 2),
                            Text(
                              budget.linkedChamaName ?? 'Chama',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.green),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.sand, size: 18),
                  onPressed: () => _showOptions(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budget.overallProgress,
                minHeight: 6,
                backgroundColor: AppColors.sand.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation(
                  isOver ? AppColors.error : AppColors.forest,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${kesFormat(budget.totalSpent)} spent',
                  style: AppTextStyles.caption.copyWith(
                    color: isOver ? AppColors.error : AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'of ${kesFormat(budget.totalIncome)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.green),
                ),
              ],
            ),

            if (budget.eventDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 11, color: AppColors.sand),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('d MMM yyyy').format(budget.eventDate!),
                    style: AppTextStyles.caption.copyWith(color: AppColors.sand),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(
                'Delete budget',
                style:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}