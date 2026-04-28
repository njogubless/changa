import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/budget/data/models/budget_model.dart';
import 'package:changa/features/budget/data/repositories/budget_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => ApiBudgetRepository(ref.watch(apiClientProvider)),
);


class BudgetListState {
  final List<BudgetModel> budgets;
  final bool isLoading;
  final String? error;

  const BudgetListState({
    this.budgets = const [],
    this.isLoading = false,
    this.error,
  });

  BudgetListState copyWith({
    List<BudgetModel>? budgets,
    bool? isLoading,
    String? error,
  }) => BudgetListState(
    budgets: budgets ?? this.budgets,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class BudgetListNotifier extends StateNotifier<BudgetListState> {
  final BudgetRepository _repo;

  BudgetListNotifier(this._repo) : super(const BudgetListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final budgets = await _repo.getBudgets();
      state = state.copyWith(budgets: budgets, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  Future<void> deleteBudget(String id) async {
    await _repo.deleteBudget(id);
    await load();
  }
}

final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, BudgetListState>(
      (ref) => BudgetListNotifier(ref.watch(budgetRepositoryProvider)),
    );



class BudgetDetailState {
  final BudgetModel? budget;
  final bool isLoading;
  final String? error;

  const BudgetDetailState({this.budget, this.isLoading = false, this.error});

  BudgetDetailState copyWith({
    BudgetModel? budget,
    bool? isLoading,
    String? error,
  }) => BudgetDetailState(
    budget: budget ?? this.budget,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class BudgetDetailNotifier extends StateNotifier<BudgetDetailState> {
  final BudgetRepository _repo;
  final String budgetId;

  BudgetDetailNotifier(this._repo, this.budgetId)
    : super(const BudgetDetailState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final budget = await _repo.getBudget(budgetId);
      state = state.copyWith(budget: budget, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addTransaction({
    required String lineItemId,
    required TransactionType type,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    try {
      final updated = await _repo.addTransaction(
        budgetId: budgetId,
        lineItemId: lineItemId,
        type: type,
        amount: amount,
        description: description,
        date: date,
      );
      state = state.copyWith(budget: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    try {
      final updated = await _repo.deleteTransaction(
        budgetId: budgetId,
        transactionId: transactionId,
      );
      state = state.copyWith(budget: updated);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final budgetDetailProvider = StateNotifierProvider.family<
  BudgetDetailNotifier,
  BudgetDetailState,
  String
>((ref, id) => BudgetDetailNotifier(ref.watch(budgetRepositoryProvider), id));



class CreateBudgetState {
  final bool isLoading;
  final BudgetModel? created;
  final String? error;

  const CreateBudgetState({this.isLoading = false, this.created, this.error});

  CreateBudgetState copyWith({
    bool? isLoading,
    BudgetModel? created,
    String? error,
  }) => CreateBudgetState(
    isLoading: isLoading ?? this.isLoading,
    created: created ?? this.created,
    error: error,
  );
}

class CreateBudgetNotifier extends StateNotifier<CreateBudgetState> {
  final BudgetRepository _repo;

  CreateBudgetNotifier(this._repo) : super(const CreateBudgetState());

  Future<void> create({
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final budget = await _repo.createBudget(
        title: title,
        type: type,
        totalIncome: totalIncome,
        lineItems: lineItems,
        eventDate: eventDate,
        linkedChamaId: linkedChamaId,
        linkedChamaName: linkedChamaName,
        linkedProjectId: linkedProjectId,
        linkedProjectName: linkedProjectName,
      );
      state = state.copyWith(isLoading: false, created: budget);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const CreateBudgetState();
}

final createBudgetProvider =
    StateNotifierProvider<CreateBudgetNotifier, CreateBudgetState>(
      (ref) => CreateBudgetNotifier(ref.watch(budgetRepositoryProvider)),
    );
