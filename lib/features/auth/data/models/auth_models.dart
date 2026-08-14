import '../../domain/entities/auth_entities.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final String currency;
  final bool isEmailVerified;
  final bool isBiometricEnabled;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.phone,
    this.currency = 'USD',
    this.isEmailVerified = false,
    this.isBiometricEnabled = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        phone: json['phone'] as String?,
        currency: json['currency'] as String? ?? 'USD',
        isEmailVerified: json['isEmailVerified'] as bool? ?? false,
        isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'avatarUrl': avatarUrl,
        'phone': phone,
        'currency': currency,
        'isEmailVerified': isEmailVerified,
        'isBiometricEnabled': isBiometricEnabled,
        'createdAt': createdAt.toIso8601String(),
      };

  UserEntity toEntity() => UserEntity(
        id: id,
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
        phone: phone,
        currency: currency,
        isEmailVerified: isEmailVerified,
        isBiometricEnabled: isBiometricEnabled,
        createdAt: createdAt,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        id: entity.id,
        email: entity.email,
        fullName: entity.fullName,
        avatarUrl: entity.avatarUrl,
        phone: entity.phone,
        currency: entity.currency,
        isEmailVerified: entity.isEmailVerified,
        isBiometricEnabled: entity.isBiometricEnabled,
        createdAt: entity.createdAt,
      );
}

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final UserModel user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthResponseModel(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );

  AuthTokensEntity toEntity() => AuthTokensEntity(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user.toEntity(),
      );
}
