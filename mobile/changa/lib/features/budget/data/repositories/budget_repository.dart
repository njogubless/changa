import 'dart:developer' as dev;

import 'package:changa/core/network/api_client.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';




void _log(String msg) => dev.log('  $msg', name: 'Budget');
void _err(String msg, [Object? e, StackTrace? st]) =>
    dev.log(' $msg', name: 'Budget', error: e, stackTrace: st, level: 1000);



String _typeToApi(BudgetType t) {
  switch (t) {
    case BudgetType.personal:          return 'personal';
    case BudgetType.event:             return 'event';
    case BudgetType.chamaContribution: return 'chama';
  }
}

BudgetType _typeFromApi(String s) {
  switch (s) {
    case 'event': return BudgetType.event;
    case 'chama': return BudgetType.chamaContribution;
    default:      return BudgetType.personal;
  }
}

BudgetCategory _catFromApi(String s) {
  switch (s) {
    case 'food':            return BudgetCategory.food;
    case 'transport':       return BudgetCategory.transport;
    case 'rent':            return BudgetCategory.rent;
    case 'utilities':       return BudgetCategory.utilities;
    case 'healthcare':      return BudgetCategory.healthcare;
    case 'education':       return BudgetCategory.education;
    case 'entertainment':   return BudgetCategory.entertainment;
    case 'clothing':        return BudgetCategory.clothing;
    case 'savings':         return BudgetCategory.savings;
    case 'venue':           return BudgetCategory.venue;
    case 'catering':        return BudgetCategory.catering;
    case 'decoration':      return BudgetCategory.decoration;
    case 'photography':     return BudgetCategory.photography;
    case 'music':           return BudgetCategory.music;
    case 'transport_event': return BudgetCategory.transport_event;
    case 'gifts':           return BudgetCategory.gifts;
    case 'contribution':    return BudgetCategory.contribution;
    default:                return BudgetCategory.other;
  }
}


BudgetLineItem _lineItemFromMap(Map<String, dynamic> j) => BudgetLineItem(
      id: j['id'] as String,
      category: _catFromApi(j['category'] as String),
      customLabel: j['custom_label'] as String?,
      allocatedAmount: (j['allocated_amount'] as num).toDouble(),
      spentAmount: (j['spent_amount'] as num?)?.toDouble() ?? 0,
    );

BudgetTransaction _txFromMap(
  Map<String, dynamic> j, {
  required String budgetId,
  required String categoryId,
}) =>
    BudgetTransaction(
      id: j['id'] as String,
      budgetId: budgetId,
      lineItemId: categoryId,
      type: TransactionType.expense,
      amount: (j['amount'] as num).toDouble(),
      description: j['description'] as String,
      date: DateTime.parse(j['date'] as String),
    );

BudgetModel _budgetFromMap(Map<String, dynamic> j) {
  final budgetId = j['id'] as String;
  final cats = (j['categories'] as List? ?? []).cast<Map<String, dynamic>>();
  final lineItems = cats.map(_lineItemFromMap).toList();
  final transactions = cats.expand((cat) {
    final catId = cat['id'] as String;
    return (cat['expenses'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map((e) => _txFromMap(e, budgetId: budgetId, categoryId: catId));
  }).toList();

  return BudgetModel(
    id: budgetId,
    title: j['title'] as String,
    type: _typeFromApi(j['type'] as String),
    totalIncome: (j['total_income'] as num).toDouble(),
    lineItems: lineItems,
    transactions: transactions,
    createdAt: DateTime.parse(j['created_at'] as String),
    eventDate: j['event_date'] != null
        ? DateTime.parse(j['event_date'] as String)
        : null,
    linkedChamaId: j['linked_chama_id'] as String?,
    linkedChamaName: j['linked_chama_name'] as String?,
    linkedProjectId: j['linked_project_id'] as String?,
    linkedProjectName: j['linked_project_name'] as String?,
  );
}

  

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

  @override
  Future<List<BudgetModel>> getBudgets() async {
    _log('→ GET /budgets');
    try {
      final res = await _api.get('/budgets');
      _log('← status=${res.statusCode}  data=${res.data}');
      final data = res.data as Map<String, dynamic>;
      final items = (data['items'] as List).cast<Map<String, dynamic>>();
      _log('   parsed ${items.length} budget(s)');
      return items.map(_budgetFromMap).toList();
    } catch (e, st) {
      _err('getBudgets failed', e, st);
      rethrow;
    }
  }

  @override
  Future<BudgetModel> getBudget(String id) async {
    _log('→ GET /budgets/$id');
    try {
      final res = await _api.get('/budgets/$id');
      _log('← status=${res.statusCode}  data=${res.data}');
      return _budgetFromMap(res.data as Map<String, dynamic>);
    } catch (e, st) {
      _err('getBudget($id) failed', e, st);
      rethrow;
    }
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
    final payload = <String, dynamic>{
      'title': title,
      'type': _typeToApi(type),
      'total_income': totalIncome,
      'categories': lineItems
          .asMap()
          .entries
          .map((e) => <String, dynamic>{
                'category': e.value.category.name,
                'custom_label': e.value.customLabel,
                'allocated_amount': e.value.allocatedAmount,
                'sort_order': e.key,
              })
          .toList(),
      if (eventDate != null) 'event_date': eventDate.toIso8601String(),
      if (linkedChamaId != null) 'linked_chama_id': linkedChamaId,
      if (linkedChamaName != null) 'linked_chama_name': linkedChamaName,
      if (linkedProjectId != null) 'linked_project_id': linkedProjectId,
      if (linkedProjectName != null) 'linked_project_name': linkedProjectName,
    };

    _log('→ POST /budgets  payload=$payload');

    try {
      final res = await _api.post('/budgets', data: payload);
      _log('← status=${res.statusCode}  data=${res.data}');
      final budget = _budgetFromMap(res.data as Map<String, dynamic>);
      _log('✅ created budget id=${budget.id} title="${budget.title}"');
      return budget;
    } catch (e, st) {
      _err('createBudget failed', e, st);
      rethrow;
    }
  }

  @override
  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final payload = <String, dynamic>{
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

    _log('→ PUT /budgets/${budget.id}  payload=$payload');

    try {
      final res = await _api.put('/budgets/${budget.id}', data: payload);
      _log('← status=${res.statusCode}  data=${res.data}');
      return _budgetFromMap(res.data as Map<String, dynamic>);
    } catch (e, st) {
      _err('updateBudget(${budget.id}) failed', e, st);
      rethrow;
    }
  }

  @override
  Future<void> deleteBudget(String id) async {
    _log('→ DELETE /budgets/$id');
    try {
      final res = await _api.delete('/budgets/$id');
      _log('← status=${res.statusCode}');
    } catch (e, st) {
      _err('deleteBudget($id) failed', e, st);
      rethrow;
    }
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
    if (type == TransactionType.income) {
      _log('ℹ️  addTransaction: income type — no API call, re-fetching');
      return getBudget(budgetId);
    }

    final payload = <String, dynamic>{
      'description': description,
      'amount': amount,
      if (date != null) 'date': date.toIso8601String(),
    };

    _log('→ POST /budgets/$budgetId/categories/$lineItemId/expenses');
    _log('   payload=$payload');

    try {
      final res = await _api.post(
        '/budgets/$budgetId/categories/$lineItemId/expenses',
        data: payload,
      );
      _log('← status=${res.statusCode}  data=${res.data}');
      return getBudget(budgetId);
    } catch (e, st) {
      _err('addTransaction failed', e, st);
      rethrow;
    }
  }

  @override
  Future<BudgetModel> deleteTransaction({
    required String budgetId,
    required String transactionId,
  }) async {
    _log('→ deleteTransaction budgetId=$budgetId txId=$transactionId');
    try {
      final budget = await getBudget(budgetId);
      final tx = budget.transactions.firstWhere(
        (t) => t.id == transactionId,
        orElse: () =>
            throw Exception('Transaction $transactionId not found'),
      );
      _log('   tx belongs to categoryId=${tx.lineItemId}');
      _log('→ DELETE /budgets/$budgetId/categories/${tx.lineItemId}/expenses/$transactionId');

      final res = await _api.delete(
        '/budgets/$budgetId/categories/${tx.lineItemId}/expenses/$transactionId',
      );
      _log('← status=${res.statusCode}');
      return getBudget(budgetId);
    } catch (e, st) {
      _err('deleteTransaction failed', e, st);
      rethrow;
    }
  }
}