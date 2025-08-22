import 'package:equatable/equatable.dart';

class ClerkEnvironment extends Equatable {
  final AuthConfig authConfig;
  final UserSettings userSettings;
  final String instanceType;

  const ClerkEnvironment({
    required this.authConfig,
    required this.userSettings,
    required this.instanceType,
  });

  factory ClerkEnvironment.fromJson(Map<String, dynamic> json) {
    return ClerkEnvironment(
      authConfig: AuthConfig.fromJson(json['auth_config']),
      userSettings: UserSettings.fromJson(json['user_settings']),
      instanceType: json['instance_type'] ?? 'development',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'auth_config': authConfig.toJson(),
      'user_settings': userSettings.toJson(),
      'instance_type': instanceType,
    };
  }

  @override
  List<Object?> get props => [authConfig, userSettings, instanceType];
}

class AuthConfig extends Equatable {
  final List<String> identificationStrategies;
  final List<String> firstFactors;
  final List<String> secondFactors;

  const AuthConfig({
    required this.identificationStrategies,
    required this.firstFactors,
    required this.secondFactors,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      identificationStrategies: List<String>.from(json['identification_strategies'] ?? []),
      firstFactors: List<String>.from(json['first_factors'] ?? []),
      secondFactors: List<String>.from(json['second_factors'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identification_strategies': identificationStrategies,
      'first_factors': firstFactors,
      'second_factors': secondFactors,
    };
  }

  @override
  List<Object?> get props => [identificationStrategies, firstFactors, secondFactors];
}

class UserSettings extends Equatable {
  final List<String> attributes;
  final Map<String, dynamic> restrictions;

  const UserSettings({
    required this.attributes,
    required this.restrictions,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      attributes: List<String>.from(json['attributes'] ?? []),
      restrictions: Map<String, dynamic>.from(json['restrictions'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'attributes': attributes,
      'restrictions': restrictions,
    };
  }

  @override
  List<Object?> get props => [attributes, restrictions];
}