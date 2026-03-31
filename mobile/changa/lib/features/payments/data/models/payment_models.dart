enum PaymentProvider { mpesa, airtel }

enum ContributionStatus { pending, success, failed, cancelled }

class ContributionModel {
  final String id;
  final String projectId;
  final double amount;
  final String currency;
  final PaymentProvider provider;
  final String phone;
  final String reference;
  final String? providerReference;
  final ContributionStatus status;
  final String? failureReason;
  final DateTime initiatedAt;
  final DateTime? completedAt;

  const ContributionModel({
    required this.id,
    required this.projectId,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.phone,
    required this.reference,
    this.providerReference,
    required this.status,
    this.failureReason,
    required this.initiatedAt,
    this.completedAt,
  });

  factory ContributionModel.fromJson(Map<String, dynamic> json) =>
      ContributionModel(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'KES',
        provider: PaymentProvider.values.firstWhere(
          (e) => e.name == json['provider'],
          orElse: () => PaymentProvider.mpesa,
        ),
        phone: json['phone'] as String,
        reference: json['reference'] as String,
        providerReference: json['provider_reference'] as String?,
        status: ContributionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ContributionStatus.pending,
        ),
        failureReason: json['failure_reason'] as String?,
        initiatedAt: DateTime.parse(json['initiated_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );
}

class ContributionStatusModel {
  final String reference;
  final ContributionStatus status;
  final String? providerReference;
  final double amount;
  final DateTime? completedAt;

  const ContributionStatusModel({
    required this.reference,
    required this.status,
    this.providerReference,
    required this.amount,
    this.completedAt,
  });

  factory ContributionStatusModel.fromJson(Map<String, dynamic> json) =>
      ContributionStatusModel(
        reference: json['reference'] as String,
        status: ContributionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ContributionStatus.pending,
        ),
        providerReference: json['provider_reference'] as String?,
        amount: (json['amount'] as num).toDouble(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );
}
