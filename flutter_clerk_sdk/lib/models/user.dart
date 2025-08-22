import 'package:equatable/equatable.dart';

class ClerkUser extends Equatable {
  final String id;
  final String? firstName;
  final String? lastName;
  final List<EmailAddress> emailAddresses;
  final List<PhoneNumber> phoneNumbers;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClerkUser({
    required this.id,
    this.firstName,
    this.lastName,
    required this.emailAddresses,
    required this.phoneNumbers,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClerkUser.fromJson(Map<String, dynamic> json) {
    return ClerkUser(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      emailAddresses: (json['email_addresses'] as List)
          .map((e) => EmailAddress.fromJson(e))
          .toList(),
      phoneNumbers: (json['phone_numbers'] as List)
          .map((e) => PhoneNumber.fromJson(e))
          .toList(),
      profileImageUrl: json['profile_image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email_addresses': emailAddresses.map((e) => e.toJson()).toList(),
      'phone_numbers': phoneNumbers.map((e) => e.toJson()).toList(),
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get fullName {
    final parts = [firstName, lastName].where((part) => part?.isNotEmpty == true);
    return parts.join(' ');
  }

  String? get primaryEmail => emailAddresses.isNotEmpty 
      ? emailAddresses.first.emailAddress 
      : null;

  String? get primaryPhone => phoneNumbers.isNotEmpty 
      ? phoneNumbers.first.phoneNumber 
      : null;

  @override
  List<Object?> get props => [
    id,
    firstName,
    lastName,
    emailAddresses,
    phoneNumbers,
    profileImageUrl,
    createdAt,
    updatedAt,
  ];
}

class EmailAddress extends Equatable {
  final String id;
  final String emailAddress;
  final EmailVerification verification;

  const EmailAddress({
    required this.id,
    required this.emailAddress,
    required this.verification,
  });

  factory EmailAddress.fromJson(Map<String, dynamic> json) {
    return EmailAddress(
      id: json['id'],
      emailAddress: json['email_address'],
      verification: EmailVerification.fromJson(json['verification']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email_address': emailAddress,
      'verification': verification.toJson(),
    };
  }

  @override
  List<Object> get props => [id, emailAddress, verification];
}

class PhoneNumber extends Equatable {
  final String id;
  final String phoneNumber;
  final PhoneVerification verification;

  const PhoneNumber({
    required this.id,
    required this.phoneNumber,
    required this.verification,
  });

  factory PhoneNumber.fromJson(Map<String, dynamic> json) {
    return PhoneNumber(
      id: json['id'],
      phoneNumber: json['phone_number'],
      verification: PhoneVerification.fromJson(json['verification']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'verification': verification.toJson(),
    };
  }

  @override
  List<Object> get props => [id, phoneNumber, verification];
}

class EmailVerification extends Equatable {
  final String status;
  final String? strategy;

  const EmailVerification({
    required this.status,
    this.strategy,
  });

  factory EmailVerification.fromJson(Map<String, dynamic> json) {
    return EmailVerification(
      status: json['status'],
      strategy: json['strategy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'strategy': strategy,
    };
  }

  bool get isVerified => status == 'verified';

  @override
  List<Object?> get props => [status, strategy];
}

class PhoneVerification extends Equatable {
  final String status;
  final String? strategy;

  const PhoneVerification({
    required this.status,
    this.strategy,
  });

  factory PhoneVerification.fromJson(Map<String, dynamic> json) {
    return PhoneVerification(
      status: json['status'],
      strategy: json['strategy'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'strategy': strategy,
    };
  }

  bool get isVerified => status == 'verified';

  @override
  List<Object?> get props => [status, strategy];
}