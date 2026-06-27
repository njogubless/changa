enum InviteStatus { pending, accepted, declined, expired }
enum InviteMethod { phone, code }

class ChamaInviteModel {
  final String id;
  final String chamaId;
  final String chamaName;
  final String? chamaDescription;
  final String invitedByName;
  final InviteMethod method;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const ChamaInviteModel({
    required this.id,
    required this.chamaId,
    required this.chamaName,
    this.chamaDescription,
    required this.invitedByName,
    required this.method,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  factory ChamaInviteModel.fromJson(Map<String, dynamic> json) =>
      ChamaInviteModel(
        id: json['id'] as String,
        chamaId: json['chama_id'] as String,
        chamaName: json['chama_name'] as String,
        chamaDescription: json['chama_description'] as String?,
        invitedByName: json['invited_by_name'] as String,
        method: InviteMethod.values.firstWhere(
          (e) => e.name == json['method'],
          orElse: () => InviteMethod.phone,
        ),
        status: InviteStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => InviteStatus.pending,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class GeneratedCodeModel {
  final String inviteCode;
  final DateTime expiresAt;
  final String chamaId;
  final String chamaName;

  const GeneratedCodeModel({
    required this.inviteCode,
    required this.expiresAt,
    required this.chamaId,
    required this.chamaName,
  });

  factory GeneratedCodeModel.fromJson(Map<String, dynamic> json) =>
      GeneratedCodeModel(
        inviteCode: json['invite_code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        chamaId: json['chama_id'] as String,
        chamaName: json['chama_name'] as String,
      );
}
