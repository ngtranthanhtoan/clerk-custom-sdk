import 'package:equatable/equatable.dart';

class SignInAttempt extends Equatable {
  final String id;
  final String status;
  final String? identifier;
  final List<AuthFactor> supportedFirstFactors;
  final AuthVerification? firstFactorVerification;
  final String? createdSessionId;

  const SignInAttempt({
    required this.id,
    required this.status,
    this.identifier,
    required this.supportedFirstFactors,
    this.firstFactorVerification,
    this.createdSessionId,
  });

  factory SignInAttempt.fromJson(Map<String, dynamic> json) {
    return SignInAttempt(
      id: json['id'],
      status: json['status'],
      identifier: json['identifier'],
      supportedFirstFactors: (json['supported_first_factors'] as List? ?? [])
          .map((e) => AuthFactor.fromJson(e))
          .toList(),
      firstFactorVerification: json['first_factor_verification'] != null
          ? AuthVerification.fromJson(json['first_factor_verification'])
          : null,
      createdSessionId: json['created_session_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'identifier': identifier,
      'supported_first_factors': supportedFirstFactors.map((e) => e.toJson()).toList(),
      'first_factor_verification': firstFactorVerification?.toJson(),
      'created_session_id': createdSessionId,
    };
  }

  bool get isComplete => status == 'complete';
  bool get needsFirstFactor => status == 'needs_first_factor';

  @override
  List<Object?> get props => [
    id,
    status,
    identifier,
    supportedFirstFactors,
    firstFactorVerification,
    createdSessionId,
  ];
}

class SignUpAttempt extends Equatable {
  final String id;
  final String status;
  final String? emailAddress;
  final String? phoneNumber;
  final String? firstName;
  final String? lastName;
  final List<String> requiredFields;
  final List<String> optionalFields;
  final List<String> missingFields;
  final List<String> unverifiedFields;
  final Map<String, AuthVerification> verifications;
  final String? createdSessionId;
  final String? createdUserId;

  const SignUpAttempt({
    required this.id,
    required this.status,
    this.emailAddress,
    this.phoneNumber,
    this.firstName,
    this.lastName,
    required this.requiredFields,
    required this.optionalFields,
    required this.missingFields,
    required this.unverifiedFields,
    required this.verifications,
    this.createdSessionId,
    this.createdUserId,
  });

  factory SignUpAttempt.fromJson(Map<String, dynamic> json) {
    final verificationsMap = json['verifications'] as Map<String, dynamic>? ?? {};
    final verifications = verificationsMap.map(
      (key, value) => MapEntry(key, AuthVerification.fromJson(value))
    );

    return SignUpAttempt(
      id: json['id'],
      status: json['status'],
      emailAddress: json['email_address'],
      phoneNumber: json['phone_number'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      requiredFields: List<String>.from(json['required_fields'] ?? []),
      optionalFields: List<String>.from(json['optional_fields'] ?? []),
      missingFields: List<String>.from(json['missing_fields'] ?? []),
      unverifiedFields: List<String>.from(json['unverified_fields'] ?? []),
      verifications: verifications,
      createdSessionId: json['created_session_id'],
      createdUserId: json['created_user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'email_address': emailAddress,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'required_fields': requiredFields,
      'optional_fields': optionalFields,
      'missing_fields': missingFields,
      'unverified_fields': unverifiedFields,
      'verifications': verifications.map((key, value) => MapEntry(key, value.toJson())),
      'created_session_id': createdSessionId,
      'created_user_id': createdUserId,
    };
  }

  bool get isComplete => status == 'complete';
  bool get needsVerification => unverifiedFields.isNotEmpty;

  @override
  List<Object?> get props => [
    id,
    status,
    emailAddress,
    phoneNumber,
    firstName,
    lastName,
    requiredFields,
    optionalFields,
    missingFields,
    unverifiedFields,
    verifications,
    createdSessionId,
    createdUserId,
  ];
}

class AuthFactor extends Equatable {
  final String strategy;
  final String? emailAddressId;
  final String? phoneNumberId;

  const AuthFactor({
    required this.strategy,
    this.emailAddressId,
    this.phoneNumberId,
  });

  factory AuthFactor.fromJson(Map<String, dynamic> json) {
    return AuthFactor(
      strategy: json['strategy'],
      emailAddressId: json['email_address_id'],
      phoneNumberId: json['phone_number_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strategy': strategy,
      'email_address_id': emailAddressId,
      'phone_number_id': phoneNumberId,
    };
  }

  bool get isPassword => strategy == 'password';
  bool get isEmailCode => strategy == 'email_code';
  bool get isPhoneCode => strategy == 'phone_code';

  @override
  List<Object?> get props => [strategy, emailAddressId, phoneNumberId];
}

class AuthVerification extends Equatable {
  final String status;
  final String strategy;
  final int attempts;
  final DateTime? expireAt;

  const AuthVerification({
    required this.status,
    required this.strategy,
    required this.attempts,
    this.expireAt,
  });

  factory AuthVerification.fromJson(Map<String, dynamic> json) {
    return AuthVerification(
      status: json['status'],
      strategy: json['strategy'],
      attempts: json['attempts'] ?? 0,
      expireAt: json['expire_at'] != null 
          ? DateTime.parse(json['expire_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'strategy': strategy,
      'attempts': attempts,
      'expire_at': expireAt?.toIso8601String(),
    };
  }

  bool get isUnverified => status == 'unverified';
  bool get isVerified => status == 'verified';
  bool get isExpired => expireAt != null && DateTime.now().isAfter(expireAt!);

  @override
  List<Object?> get props => [status, strategy, attempts, expireAt];
}