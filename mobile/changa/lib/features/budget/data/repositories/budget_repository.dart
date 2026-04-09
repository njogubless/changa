import 'dart:convert';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:changa/core/network/api_client.dart'; // adjust to your actual ApiClient path
// import 'budget_repository.dart'; // Removed self-import to avoid circular dependency

// ── Mapping helpers ────────────────────────────────────────────────────────────
//
//  Flutter model  ↔  API field
//  ─────────────────────────────────────────────────────
//  BudgetLineItem      ↔  BudgetCategory  (backend name)
//  BudgetTransaction   ↔  BudgetExpense   (backend name)
//  BudgetType.chamaContribution  ↔  "chama"
//  lineItemId          ↔  category_id
//  spentAmount         ↔  spent_amount
//  allocatedAmount     ↔  allocated_amount

// ── Type converters ────────────────────────────────────────────────────────────

String _budgetTypeToApi(BudgetType t) {
  switch (t) {
    case BudgetType.personal:
      return 'personal';
    case BudgetType.event:
      return 'event';
    case BudgetType.chamaContribution:
      return 'chama';
  }
}

BudgetType _budgetTypeFromApi(String s) {
  switch (s) {
    case 'event':
      return BudgetType.event;
    case 'chama':
      return BudgetType.chamaContribution;
    default:
      return BudgetType.personal;
  }
}

/// Maps API category string → Flutter BudgetCategory enum.
/// Falls back to [BudgetCategory.other] for unknown values.
BudgetCategory _categoryFromApi(String s) {
  switch (s) {
    case 'food':
      return BudgetCategory.food;
    case 'transport':
      return BudgetCategory.transport;
    case 'rent':
      return BudgetCategory.rent;
    case 'utilities':
      return BudgetCategory.utilities;
    case 'healthcare':
      return BudgetCategory.healthcare;
    case 'education':
      return BudgetCategory.education;
    case 'entertainment':
      return BudgetCategory.entertainment;
    case 'clothing':
      return BudgetCategory.clothing;
    case 'savings':
      return BudgetCategory.savings;
    case 'venue':
      return BudgetCategory.venue;
    case 'catering':
      return BudgetCategory.catering;
    case 'decoration':
      return BudgetCategory.decoration;
    case 'photography':
      return BudgetCategory.photography;
    case 'music':
      return BudgetCategory.music;
    case 'transport_event':
      return BudgetCategory.transport_event;
    case 'gifts':
      return BudgetCategory.gifts;
    case 'contribution':
      return BudgetCategory.contribution;
    default:
      return BudgetCategory.other;
  }
}

String _categoryToApi(BudgetCategory c) => c.name;

// ── JSON → Flutter model converters ───────────────────────────────────────────

BudgetLineItem _lineItemFromJson(Map<String, dynamic> j) => BudgetLineItem(
  id: j['id'],
  category: _categoryFromApi(j['category'] as String),
  customLabel: j['custom_label'] as String?,
  allocatedAmount: (j['allocated_amount'] as num).toDouble(),
  spentAmount: (j['spent_amount'] as num?)?.toDouble() ?? 0,
);

/// The API stores expenses inside each category object.
/// We flatten them into a single list on the BudgetModel.
BudgetTransaction _transactionFromJson(
  Map<String, dynamic> j, {
  required String budgetId,
  required String categoryId,
}) => BudgetTransaction(
  id: j['id'],
  budgetId: budgetId,
  lineItemId: categoryId,
  // The API only has expenses — no income transactions
  type: TransactionType.expense,
  amount: (j['amount'] as num).toDouble(),
  description: j['description'] as String,
  date: DateTime.parse(j['date'] as String),
);

BudgetModel _budgetFromJson(Map<String, dynamic> j) {
  final budgetId = j['id'] as String;

  final categories =
      (j['categories'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  final lineItems = categories.map(_lineItemFromJson).toList();

  // Flatten all expenses from all categories into one transactions list
  final transactions =
      categories.expand((cat) {
        final catId = cat['id'] as String;
        final expenses =
            (cat['expenses'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        return expenses.map(
          (e) => _transactionFromJson(e, budgetId: budgetId, categoryId: catId),
        );
      }).toList();

  return BudgetModel(
    id: budgetId,
    title: j['title'] as String,
    type: _budgetTypeFromApi(j['type'] as String),
    totalIncome: (j['total_income'] as num).toDouble(),
    lineItems: lineItems,
    transactions: transactions,
    createdAt: DateTime.parse(j['created_at'] as String),
    eventDate:
        j['event_date'] != null
            ? DateTime.parse(j['event_date'] as String)
            : null,
    linkedChamaId: j['linked_chama_id'] as String?,
    linkedChamaName: j['linked_chama_name'] as String?,
    linkedProjectId: j['linked_project_id'] as String?,
    linkedProjectName: j['linked_project_name'] as String?,
  );
}

// ── API Repository ─────────────────────────────────────────────────────────────

// Ensure BudgetRepository is an abstract class or mixin in your codebase.
// If it is not defined, define it as follows:
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

class ApiBudgetRepository implements BudgetRepository {
  final ApiClient _api;

  const ApiBudgetRepository(this._api);

  // ── Budgets ──────────────────────────────────────────────────────────────

  @override
  Future<List<BudgetModel>> getBudgets() async {
    final response = await _api.get('/budgets');
    final data = jsonDecode(response.data) as Map<String, dynamic>;
    final items = (data['items'] as List).cast<Map<String, dynamic>>();
    return items.map(_budgetFromJson).toList();
  }

  @override
  Future<BudgetModel> getBudget(String id) async {
    final response = await _api.get('/budgets/$id');
    return _budgetFromJson(jsonDecode(response.data) as Map<String, dynamic>);
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
    final body = {
      'title': title,
      'type': _budgetTypeToApi(type),
      'total_income': totalIncome,
      'categories':
          lineItems
              .map(
                (item) => {
                  'category': _categoryToApi(item.category),
                  'custom_label': item.customLabel,
                  'allocated_amount': item.allocatedAmount,
                  'sort_order': lineItems.indexOf(item),
                },
              )
              .toList(),
      if (eventDate != null) 'event_date': eventDate.toIso8601String(),
      if (linkedChamaId != null) 'linked_chama_id': linkedChamaId,
      if (linkedChamaName != null) 'linked_chama_name': linkedChamaName,
      if (linkedProjectId != null) 'linked_project_id': linkedProjectId,
      if (linkedProjectName != null) 'linked_project_name': linkedProjectName,
    };

    final response = await _api.post('/budgets', data: body);
    return _budgetFromJson(jsonDecode(response.data) as Map<String, dynamic>);
  }

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final body = {
      'title': budget.title,
      'total_income': budget.totalIncome,
      if (budget.eventDate != null)
        'event_date': budget.eventDate!.toIso8601String(),
      if (budget.linkedChamaId != null) 'linked_chama_id': budget.linkedChamaId,
      if (budget.linkedChamaName != null)
        'linked_chama_name': budget.linkedChamaName,
      if (budget.linkedProjectId != null)
        'linked_project_id': budget.linkedProjectId,
      if (budget.linkedProjectName != null)
        'linked_project_name': budget.linkedProjectName,
    };

    final response = await _api.put('/budgets/${budget.id}', data: body);
    return _budgetFromJson(jsonDecode(response.data) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteBudget(String id) async {
    await _api.delete('/budgets/$id');
  }

  // ── Expenses (mapped from Flutter's "transactions") ───────────────────────
  //
  //  Flutter's addTransaction takes a lineItemId — that maps directly to
  //  the API's category_id, so we use it in the URL path.

  @override
  Future<BudgetModel> addTransaction({
    required String budgetId,
    required String lineItemId, // == category_id on the API
    required TransactionType type,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    // The API only supports expenses. Income transactions aren't persisted
    // server-side, so we skip posting them and just return the current budget.
    if (type == TransactionType.income) {
      return getBudget(budgetId);
    }

    final body = {
      'description': description,
      'amount': amount,
      if (date != null) 'date': date.toIso8601String(),
    };

    await _api.post(
      '/budgets/$budgetId/categories/$lineItemId/expenses',
      data: body,
    );

    // Re-fetch the full budget so spent_amount totals are up to date
    return getBudget(budgetId);
  }

  @override
  Future<BudgetModel> deleteTransaction({
    required String budgetId,
    required String transactionId,
  }) async {
    // We need the categoryId to build the URL. Fetch the budget first to find it.
    final budget = await getBudget(budgetId);
    final tx = budget.transactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => throw Exception('Transaction not found'),
    );

    await _api.delete(
      '/budgets/$budgetId/categories/${tx.lineItemId}/expenses/$transactionId',
    );

    // Re-fetch to get updated spent_amount totals
    return getBudget(budgetId);
  }
}
