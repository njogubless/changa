import 'dart:convert';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';


// ── Repository interface (swap for API implementation later) ───────────────

abstract class BudgetRepository {
  Future<List<BudgetModel>> getBudgets();
  Future<BudgetModel> getBudget(String id);
  Future<BudgetModel> createBudget({
    required String title,
    required BudgetType type,
    required double totalIncome,
    required List<BudgetLineItem> lineItems,
    DateTime? eventDate,
    String? linkedChamaId,
    String? linkedChamaName,
    String? linkedProjectId,
    String? linkedProjectName,
  });
  Future<BudgetModel> updateBudget(BudgetModel budget);
  Future<void> deleteBudget(String id);
  Future<BudgetModel> addTransaction({
    required String budgetId,
    required String lineItemId,
    required TransactionType type,
    required double amount,
    required String description,
    DateTime? date,
  });
  Future<BudgetModel> deleteTransaction({
    required String budgetId,
    required String transactionId,
  });
}

// ── Local implementation (SharedPreferences) ───────────────────────────────

class LocalBudgetRepository implements BudgetRepository {
  static const _key = 'changa_budgets';
  final _uuid = const Uuid();

  Future<List<BudgetModel>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => BudgetModel.fromJson(e)).toList();
  }

  Future<void> _save(List<BudgetModel> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(budgets.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<List<BudgetModel>> getBudgets() => _load();

  @override
  Future<BudgetModel> getBudget(String id) async {
    final budgets = await _load();
    return budgets.firstWhere((b) => b.id == id);
  }

  @override
  Future<BudgetModel> createBudget({
    required String title,
    required BudgetType type,
    required double totalIncome,
    required List<BudgetLineItem> lineItems,
    DateTime? eventDate,
    String? linkedChamaId,
    String? linkedChamaName,
    String? linkedProjectId,
    String? linkedProjectName,
  }) async {
    final budget = BudgetModel(
      id: _uuid.v4(),
      title: title,
      type: type,
      totalIncome: totalIncome,
      lineItems: lineItems,
      createdAt: DateTime.now(),
      eventDate: eventDate,
      linkedChamaId: linkedChamaId,
      linkedChamaName: linkedChamaName,
      linkedProjectId: linkedProjectId,
      linkedProjectName: linkedProjectName,
    );
    final budgets = await _load();
    budgets.insert(0, budget);
    await _save(budgets);
    return budget;
  }

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final budgets = await _load();
    final idx = budgets.indexWhere((b) => b.id == budget.id);
    if (idx == -1) throw Exception('Budget not found');
    budgets[idx] = budget;
    await _save(budgets);
    return budget;
  }

  @override
  Future<void> deleteBudget(String id) async {
    final budgets = await _load();
    budgets.removeWhere((b) => b.id == id);
    await _save(budgets);
  }

  @override
  Future<BudgetModel> addTransaction({
    required String budgetId,
    required String lineItemId,
    required TransactionType type,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    final budgets = await _load();
    final idx = budgets.indexWhere((b) => b.id == budgetId);
    if (idx == -1) throw Exception('Budget not found');

    final tx = BudgetTransaction(
      id: _uuid.v4(),
      budgetId: budgetId,
      lineItemId: lineItemId,
      type: type,
      amount: amount,
      description: description,
      date: date ?? DateTime.now(),
    );

    // Update spent amount on the relevant line item
    final budget = budgets[idx];
    final updatedItems = budget.lineItems.map((item) {
      if (item.id != lineItemId) return item;
      final delta = type == TransactionType.expense ? amount : -amount;
      return item.copyWith(spentAmount: (item.spentAmount + delta).clamp(0, double.infinity));
    }).toList();

    final updated = budget.copyWith(
      lineItems: updatedItems,
      transactions: [...budget.transactions, tx],
    );
    budgets[idx] = updated;
    await _save(budgets);
    return updated;
  }

  @override
  Future<BudgetModel> deleteTransaction({
    required String budgetId,
    required String transactionId,
  }) async {
    final budgets = await _load();
    final idx = budgets.indexWhere((b) => b.id == budgetId);
    if (idx == -1) throw Exception('Budget not found');

    final budget = budgets[idx];
    final tx = budget.transactions.firstWhere((t) => t.id == transactionId);

    // Reverse the spent amount
    final updatedItems = budget.lineItems.map((item) {
      if (item.id != tx.lineItemId) return item;
      final delta = tx.type == TransactionType.expense ? -tx.amount : tx.amount;
      return item.copyWith(spentAmount: (item.spentAmount + delta).clamp(0, double.infinity));
    }).toList();

    final updated = budget.copyWith(
      lineItems: updatedItems,
      transactions: budget.transactions.where((t) => t.id != transactionId).toList(),
    );
    budgets[idx] = updated;
    await _save(budgets);
    return updated;
  }
}