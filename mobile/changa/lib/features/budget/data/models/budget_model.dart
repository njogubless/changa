import 'package:flutter/material.dart';



enum BudgetType { personal, event, chamaContribution }

enum BudgetCategory {
  
  food,
  transport,
  rent,
  utilities,
  healthcare,
  education,
  entertainment,
  clothing,
  savings,
  
  venue,
  catering,
  decoration,
  photography,
  music,
  transport_event,
  gifts,

  contribution,
  
  other,
}

enum TransactionType { income, expense }


extension BudgetTypeX on BudgetType {
  String get label {
    switch (this) {
      case BudgetType.personal:
        return 'Personal';
      case BudgetType.event:
        return 'Event';
      case BudgetType.chamaContribution:
        return 'Chama';
    }
  }

  IconData get icon {
    switch (this) {
      case BudgetType.personal:
        return Icons.person_outline;
      case BudgetType.event:
        return Icons.celebration_outlined;
      case BudgetType.chamaContribution:
        return Icons.people_outline;
    }
  }
}

extension BudgetCategoryX on BudgetCategory {
  String get label {
    switch (this) {
      case BudgetCategory.food:
        return 'Food & Groceries';
      case BudgetCategory.transport:
        return 'Transport';
      case BudgetCategory.rent:
        return 'Rent & Housing';
      case BudgetCategory.utilities:
        return 'Utilities';
      case BudgetCategory.healthcare:
        return 'Healthcare';
      case BudgetCategory.education:
        return 'Education';
      case BudgetCategory.entertainment:
        return 'Entertainment';
      case BudgetCategory.clothing:
        return 'Clothing';
      case BudgetCategory.savings:
        return 'Savings';
      case BudgetCategory.venue:
        return 'Venue';
      case BudgetCategory.catering:
        return 'Catering';
      case BudgetCategory.decoration:
        return 'Decoration';
      case BudgetCategory.photography:
        return 'Photography';
      case BudgetCategory.music:
        return 'Music & Entertainment';
      case BudgetCategory.transport_event:
        return 'Transport';
      case BudgetCategory.gifts:
        return 'Gifts & Favours';
      case BudgetCategory.contribution:
        return 'Chama Contribution';
      case BudgetCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case BudgetCategory.food:
        return Icons.restaurant_outlined;
      case BudgetCategory.transport:
      case BudgetCategory.transport_event:
        return Icons.directions_car_outlined;
      case BudgetCategory.rent:
        return Icons.home_outlined;
      case BudgetCategory.utilities:
        return Icons.bolt_outlined;
      case BudgetCategory.healthcare:
        return Icons.local_hospital_outlined;
      case BudgetCategory.education:
        return Icons.school_outlined;
      case BudgetCategory.entertainment:
        return Icons.movie_outlined;
      case BudgetCategory.clothing:
        return Icons.checkroom_outlined;
      case BudgetCategory.savings:
        return Icons.savings_outlined;
      case BudgetCategory.venue:
        return Icons.location_city_outlined;
      case BudgetCategory.catering:
        return Icons.restaurant_menu_outlined;
      case BudgetCategory.decoration:
        return Icons.auto_awesome_outlined;
      case BudgetCategory.photography:
        return Icons.camera_alt_outlined;
      case BudgetCategory.music:
        return Icons.music_note_outlined;
      case BudgetCategory.gifts:
        return Icons.card_giftcard_outlined;
      case BudgetCategory.contribution:
        return Icons.people_outline;
      case BudgetCategory.other:
        return Icons.more_horiz;
    }
  }
}



class BudgetLineItem {
  final String id;
  final BudgetCategory category;
  final String? customLabel;
  final double allocatedAmount;
  final double spentAmount;

  const BudgetLineItem({
    required this.id,
    required this.category,
    this.customLabel,
    required this.allocatedAmount,
    this.spentAmount = 0,
  });

  String get label => customLabel ?? category.label;
  double get remaining => allocatedAmount - spentAmount;
  double get progress =>
      allocatedAmount > 0 ? (spentAmount / allocatedAmount).clamp(0, 1) : 0;
  bool get isOverBudget => spentAmount > allocatedAmount;

  BudgetLineItem copyWith({
    double? allocatedAmount,
    double? spentAmount,
    String? customLabel,
  }) =>
      BudgetLineItem(
        id: id,
        category: category,
        customLabel: customLabel ?? this.customLabel,
        allocatedAmount: allocatedAmount ?? this.allocatedAmount,
        spentAmount: spentAmount ?? this.spentAmount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'customLabel': customLabel,
        'allocatedAmount': allocatedAmount,
        'spentAmount': spentAmount,
      };

  factory BudgetLineItem.fromJson(Map<String, dynamic> j) => BudgetLineItem(
        id: j['id'],
        category: BudgetCategory.values.byName(j['category']),
        customLabel: j['customLabel'],
        allocatedAmount: (j['allocatedAmount'] as num).toDouble(),
        spentAmount: (j['spentAmount'] as num?)?.toDouble() ?? 0,
      );
}

class BudgetTransaction {
  final String id;
  final String budgetId;
  final String lineItemId;
  final TransactionType type;
  final double amount;
  final String description;
  final DateTime date;

  const BudgetTransaction({
    required this.id,
    required this.budgetId,
    required this.lineItemId,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'lineItemId': lineItemId,
        'type': type.name,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String(),
      };

  factory BudgetTransaction.fromJson(Map<String, dynamic> j) =>
      BudgetTransaction(
        id: j['id'],
        budgetId: j['budgetId'],
        lineItemId: j['lineItemId'],
        type: TransactionType.values.byName(j['type']),
        amount: (j['amount'] as num).toDouble(),
        description: j['description'],
        date: DateTime.parse(j['date']),
      );
}

class BudgetModel {
  final String id;
  final String title;
  final BudgetType type;
  final double totalIncome;
  final List<BudgetLineItem> lineItems;
  final List<BudgetTransaction> transactions;
  final DateTime createdAt;
  final DateTime? eventDate;
  final String? linkedChamaId;
  final String? linkedChamaName;
  final String? linkedProjectId;
  final String? linkedProjectName;

  const BudgetModel({
    required this.id,
    required this.title,
    required this.type,
    required this.totalIncome,
    required this.lineItems,
    this.transactions = const [],
    required this.createdAt,
    this.eventDate,
    this.linkedChamaId,
    this.linkedChamaName,
    this.linkedProjectId,
    this.linkedProjectName,
  });

  double get totalAllocated =>
      lineItems.fold(0, (s, i) => s + i.allocatedAmount);
  double get totalSpent => lineItems.fold(0, (s, i) => s + i.spentAmount);
  double get unallocated => totalIncome - totalAllocated;
  double get remaining => totalIncome - totalSpent;
  double get overallProgress =>
      totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0, 1) : 0;
  bool get isLinkedToChama => linkedChamaId != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'totalIncome': totalIncome,
        'lineItems': lineItems.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'eventDate': eventDate?.toIso8601String(),
        'linkedChamaId': linkedChamaId,
        'linkedChamaName': linkedChamaName,
        'linkedProjectId': linkedProjectId,
        'linkedProjectName': linkedProjectName,
      };

  factory BudgetModel.fromJson(Map<String, dynamic> j) => BudgetModel(
        id: j['id'],
        title: j['title'],
        type: BudgetType.values.byName(j['type']),
        totalIncome: (j['totalIncome'] as num).toDouble(),
        lineItems: (j['lineItems'] as List)
            .map((e) => BudgetLineItem.fromJson(e))
            .toList(),
        transactions: (j['transactions'] as List?)
                ?.map((e) => BudgetTransaction.fromJson(e))
                .toList() ??
            [],
        createdAt: DateTime.parse(j['createdAt']),
        eventDate:
            j['eventDate'] != null ? DateTime.parse(j['eventDate']) : null,
        linkedChamaId: j['linkedChamaId'],
        linkedChamaName: j['linkedChamaName'],
        linkedProjectId: j['linkedProjectId'],
        linkedProjectName: j['linkedProjectName'],
      );

  BudgetModel copyWith({
    String? title,
    double? totalIncome,
    List<BudgetLineItem>? lineItems,
    List<BudgetTransaction>? transactions,
    DateTime? eventDate,
    String? linkedChamaId,
    String? linkedChamaName,
    String? linkedProjectId,
    String? linkedProjectName,
  }) =>
      BudgetModel(
        id: id,
        title: title ?? this.title,
        type: type,
        totalIncome: totalIncome ?? this.totalIncome,
        lineItems: lineItems ?? this.lineItems,
        transactions: transactions ?? this.transactions,
        createdAt: createdAt,
        eventDate: eventDate ?? this.eventDate,
        linkedChamaId: linkedChamaId ?? this.linkedChamaId,
        linkedChamaName: linkedChamaName ?? this.linkedChamaName,
        linkedProjectId: linkedProjectId ?? this.linkedProjectId,
        linkedProjectName: linkedProjectName ?? this.linkedProjectName,
      );
}