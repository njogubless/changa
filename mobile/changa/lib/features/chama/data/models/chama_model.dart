enum ChamaMemberRole { owner, admin, member }
enum PaymentAccountType { paybill, till, pochi }

// ── Chama ──────────────────────────────────────────────────────────────────

class ChamaModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String avatarColor;
  final String inviteCode;
  final bool isActive;
  final int memberCount;
  final int activeProjectCount;
  final DateTime createdAt;

  const ChamaModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.avatarColor,
    required this.inviteCode,
    required this.isActive,
    required this.memberCount,
    required this.activeProjectCount,
    required this.createdAt,
  });

  factory ChamaModel.fromJson(Map<String, dynamic> json) => ChamaModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        avatarColor: json['avatar_color'] as String? ?? '#1B4332',
        inviteCode: json['invite_code'] as String,
        isActive: json['is_active'] as bool? ?? true,
        memberCount: json['member_count'] as int? ?? 0,
        activeProjectCount: json['active_project_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ChamaMemberModel {
  final String userId;
  final String fullName;
  final String email;
  final ChamaMemberRole role;
  final DateTime joinedAt;

  const ChamaMemberModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.joinedAt,
  });

  factory ChamaMemberModel.fromJson(Map<String, dynamic> json) =>
      ChamaMemberModel(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        role: ChamaMemberRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => ChamaMemberRole.member,
        ),
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );
}

class ChamaListResponse {
  final List<ChamaModel> items;
  final int total;

  const ChamaListResponse({required this.items, required this.total});

  factory ChamaListResponse.fromJson(Map<String, dynamic> json) =>
      ChamaListResponse(
        items: (json['items'] as List)
            .map((e) => ChamaModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
      );
}