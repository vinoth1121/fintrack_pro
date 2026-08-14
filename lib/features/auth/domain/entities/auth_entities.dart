import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? phone;
  final String currency;
  final bool isEmailVerified;
  final bool isBiometricEnabled;
  final DateTime createdAt;

  const UserEntity({
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

  UserEntity copyWith({
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? currency,
    bool? isEmailVerified,
    bool? isBiometricEnabled,
  }) {
    return UserEntity(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      currency: currency ?? this.currency,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id, email, fullName, avatarUrl, phone, currency,
    isEmailVerified, isBiometricEnabled, createdAt,
  ];
}

class AuthTokensEntity extends Equatable {
  final String accessToken;
  final String refreshToken;
  final UserEntity user;

  const AuthTokensEntity({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  @override
  List<Object?> get props => [accessToken, refreshToken, user];
}
