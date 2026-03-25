class UserModel {
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    this.avatarUrl,
    required this.isVerified,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? fullName,
    String? avatarUrl,
  }) => UserModel(
        id: id,
        email: email,
        phone: phone,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isVerified: isVerified,
        createdAt: createdAt,
      );
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}
