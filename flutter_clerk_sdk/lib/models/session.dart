import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'user.dart';
import 'organization.dart';

class ClerkSession extends Equatable {
  final String id;
  final String status;
  final ClerkUser user;
  final ClerkOrganization? organization;
  final DateTime expireAt;
  final DateTime abandonAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClerkSession({
    required this.id,
    required this.status,
    required this.user,
    this.organization,
    required this.expireAt,
    required this.abandonAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClerkSession.fromJson(Map<String, dynamic> json) {
    return ClerkSession(
      id: json['id'],
      status: json['status'],
      user: ClerkUser.fromJson(json['user']),
      organization: json['organization'] != null 
          ? ClerkOrganization.fromJson(json['organization'])
          : null,
      expireAt: DateTime.parse(json['expire_at']),
      abandonAt: DateTime.parse(json['abandon_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'user': user.toJson(),
      'organization': organization?.toJson(),
      'expire_at': expireAt.toIso8601String(),
      'abandon_at': abandonAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == 'active' && DateTime.now().isBefore(expireAt);
  bool get isExpired => DateTime.now().isAfter(expireAt);
  bool get isAbandoned => DateTime.now().isAfter(abandonAt);

  Duration get timeUntilExpiry {
    final now = DateTime.now();
    if (expireAt.isBefore(now)) {
      return Duration.zero;
    }
    return expireAt.difference(now);
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  @override
  List<Object?> get props => [
    id,
    status,
    user,
    organization,
    expireAt,
    abandonAt,
    createdAt,
    updatedAt,
  ];
}