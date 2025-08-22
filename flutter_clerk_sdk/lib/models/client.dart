import 'package:equatable/equatable.dart';
import 'session.dart';

class ClerkClient extends Equatable {
  final String id;
  final List<ClerkSession> sessions;
  final String? lastActiveSessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClerkClient({
    required this.id,
    required this.sessions,
    this.lastActiveSessionId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClerkClient.fromJson(Map<String, dynamic> json) {
    return ClerkClient(
      id: json['id'],
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((sessionJson) => ClerkSession.fromJson(sessionJson))
          .toList() ?? [],
      lastActiveSessionId: json['last_active_session_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessions': sessions.map((session) => session.toJson()).toList(),
      'last_active_session_id': lastActiveSessionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, sessions, lastActiveSessionId, createdAt, updatedAt];
}