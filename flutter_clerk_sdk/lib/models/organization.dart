import 'package:equatable/equatable.dart';

class ClerkOrganization extends Equatable {
  final String id;
  final String name;
  final String slug;
  final int membersCount;
  final int pendingInvitationsCount;
  final String? logoUrl;
  final Map<String, dynamic> publicMetadata;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClerkOrganization({
    required this.id,
    required this.name,
    required this.slug,
    required this.membersCount,
    required this.pendingInvitationsCount,
    this.logoUrl,
    required this.publicMetadata,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClerkOrganization.fromJson(Map<String, dynamic> json) {
    return ClerkOrganization(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      membersCount: json['members_count'] ?? 0,
      pendingInvitationsCount: json['pending_invitations_count'] ?? 0,
      logoUrl: json['logo_url'],
      publicMetadata: json['public_metadata'] ?? {},
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'members_count': membersCount,
      'pending_invitations_count': pendingInvitationsCount,
      'logo_url': logoUrl,
      'public_metadata': publicMetadata,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    slug,
    membersCount,
    pendingInvitationsCount,
    logoUrl,
    publicMetadata,
    createdBy,
    createdAt,
    updatedAt,
  ];
}

class OrganizationMembership extends Equatable {
  final String id;
  final String role;
  final String organizationId;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrganizationMembership({
    required this.id,
    required this.role,
    required this.organizationId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationMembership.fromJson(Map<String, dynamic> json) {
    return OrganizationMembership(
      id: json['id'],
      role: json['role'],
      organizationId: json['organization_id'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'organization_id': organizationId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';

  @override
  List<Object> get props => [
    id,
    role,
    organizationId,
    userId,
    createdAt,
    updatedAt,
  ];
}