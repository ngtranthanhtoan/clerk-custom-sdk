import '../models/auth_attempt.dart';
import '../services/clerk_service.dart';

class SignUpFlow {
  final ClerkService _service;
  SignUpAttempt? _signUpAttempt;

  SignUpFlow(this._service);

  SignUpAttempt? get currentAttempt => _signUpAttempt;

  Future<SignUpAttempt> create(Map<String, dynamic> userData) async {
    try {
      print('🔄 Creating sign-up attempt...');
      print('📝 User data: ${userData.keys.join(', ')}');
      
      final data = await _service.request(
        '/client/sign_ups',
        method: 'POST',
        body: userData,
      );

      _signUpAttempt = SignUpAttempt.fromJson(data['response']);
      
      print('✅ Sign-up attempt created: ${_signUpAttempt!.id}');
      print('📋 Status: ${_signUpAttempt!.status}');
      print('⚠️ Unverified fields: ${_signUpAttempt!.unverifiedFields.join(', ')}');
      
      return _signUpAttempt!;
    } catch (e) {
      print('❌ Failed to create sign-up: $e');
      rethrow;
    }
  }

  Future<SignUpAttempt> prepareEmailVerification() async {
    if (_signUpAttempt == null) {
      throw Exception('Must create sign-up attempt first');
    }

    if (!_signUpAttempt!.unverifiedFields.contains('email_address')) {
      throw Exception('Email address does not need verification');
    }

    try {
      print('📧 Preparing email verification...');
      
      final data = await _service.request(
        '/client/sign_ups/${_signUpAttempt!.id}/prepare_verification',
        method: 'POST',
        body: {'strategy': 'email_code'},
      );

      _signUpAttempt = SignUpAttempt.fromJson(data['response']);
      
      print('✅ Email verification code sent');
      
      return _signUpAttempt!;
    } catch (e) {
      print('❌ Failed to prepare email verification: $e');
      rethrow;
    }
  }

  Future<SignUpAttempt> verifyEmail(String code) async {
    if (_signUpAttempt == null) {
      throw Exception('Must create sign-up attempt first');
    }

    if (!_signUpAttempt!.verifications.containsKey('email_address')) {
      throw Exception('Email verification not prepared');
    }

    try {
      print('🔄 Verifying email with code: $code');
      
      final data = await _service.request(
        '/client/sign_ups/${_signUpAttempt!.id}/attempt_verification',
        method: 'POST',
        body: {
          'strategy': 'email_code',
          'code': code,
        },
      );

      _signUpAttempt = SignUpAttempt.fromJson(data['response']);

      if (_signUpAttempt!.isComplete) {
        print('🎉 Account created and verified successfully!');
        print('👤 User ID: ${_signUpAttempt!.createdUserId}');
        print('🎫 Session ID: ${_signUpAttempt!.createdSessionId}');
      } else {
        print('⚠️ Email verification incomplete: ${_signUpAttempt!.status}');
        if (_signUpAttempt!.unverifiedFields.isNotEmpty) {
          print('🔍 Still need to verify: ${_signUpAttempt!.unverifiedFields.join(', ')}');
        }
      }

      return _signUpAttempt!;
    } catch (e) {
      print('❌ Email verification failed: $e');
      rethrow;
    }
  }

  Future<SignUpAttempt> preparePhoneVerification() async {
    if (_signUpAttempt == null) {
      throw Exception('Must create sign-up attempt first');
    }

    if (!_signUpAttempt!.unverifiedFields.contains('phone_number')) {
      throw Exception('Phone number does not need verification');
    }

    try {
      print('📱 Preparing phone verification...');
      
      final data = await _service.request(
        '/client/sign_ups/${_signUpAttempt!.id}/prepare_verification',
        method: 'POST',
        body: {'strategy': 'phone_code'},
      );

      _signUpAttempt = SignUpAttempt.fromJson(data['response']);
      
      print('✅ Phone verification code sent');
      
      return _signUpAttempt!;
    } catch (e) {
      print('❌ Failed to prepare phone verification: $e');
      rethrow;
    }
  }

  Future<SignUpAttempt> verifyPhone(String code) async {
    if (_signUpAttempt == null) {
      throw Exception('Must create sign-up attempt first');
    }

    if (!_signUpAttempt!.verifications.containsKey('phone_number')) {
      throw Exception('Phone verification not prepared');
    }

    try {
      print('🔄 Verifying phone with code: $code');
      
      final data = await _service.request(
        '/client/sign_ups/${_signUpAttempt!.id}/attempt_verification',
        method: 'POST',
        body: {
          'strategy': 'phone_code',
          'code': code,
        },
      );

      _signUpAttempt = SignUpAttempt.fromJson(data['response']);

      if (_signUpAttempt!.isComplete) {
        print('🎉 Account created and verified successfully!');
        print('👤 User ID: ${_signUpAttempt!.createdUserId}');
        print('🎫 Session ID: ${_signUpAttempt!.createdSessionId}');
      } else {
        print('⚠️ Phone verification incomplete: ${_signUpAttempt!.status}');
        if (_signUpAttempt!.unverifiedFields.isNotEmpty) {
          print('🔍 Still need to verify: ${_signUpAttempt!.unverifiedFields.join(', ')}');
        }
      }

      return _signUpAttempt!;
    } catch (e) {
      print('❌ Phone verification failed: $e');
      rethrow;
    }
  }

  // Convenience methods
  Future<SignUpAttempt> signUpWithEmail(
    String emailAddress,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final userData = <String, dynamic>{
      'email_address': emailAddress,
      'password': password,
    };

    if (firstName != null) userData['first_name'] = firstName;
    if (lastName != null) userData['last_name'] = lastName;

    await create(userData);
    return await prepareEmailVerification();
  }

  Future<SignUpAttempt> signUpWithPhone(
    String phoneNumber,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    final userData = <String, dynamic>{
      'phone_number': phoneNumber,
      'password': password,
    };

    if (firstName != null) userData['first_name'] = firstName;
    if (lastName != null) userData['last_name'] = lastName;

    await create(userData);
    return await preparePhoneVerification();
  }

  // Helper methods
  bool needsEmailVerification() {
    return _signUpAttempt?.unverifiedFields.contains('email_address') ?? false;
  }

  bool needsPhoneVerification() {
    return _signUpAttempt?.unverifiedFields.contains('phone_number') ?? false;
  }

  bool isEmailVerificationPrepared() {
    return _signUpAttempt?.verifications.containsKey('email_address') ?? false;
  }

  bool isPhoneVerificationPrepared() {
    return _signUpAttempt?.verifications.containsKey('phone_number') ?? false;
  }

  AuthVerification? getEmailVerification() {
    return _signUpAttempt?.verifications['email_address'];
  }

  AuthVerification? getPhoneVerification() {
    return _signUpAttempt?.verifications['phone_number'];
  }

  List<String> getMissingFields() {
    return _signUpAttempt?.missingFields ?? [];
  }

  List<String> getUnverifiedFields() {
    return _signUpAttempt?.unverifiedFields ?? [];
  }

  bool canComplete() {
    if (_signUpAttempt == null) return false;
    return _signUpAttempt!.missingFields.isEmpty && 
           _signUpAttempt!.unverifiedFields.isEmpty;
  }

  // Check verification status
  bool isVerificationExpired(String field) {
    final verification = _signUpAttempt?.verifications[field];
    return verification?.isExpired ?? false;
  }

  int getVerificationAttempts(String field) {
    final verification = _signUpAttempt?.verifications[field];
    return verification?.attempts ?? 0;
  }

  Duration? getVerificationTimeRemaining(String field) {
    final verification = _signUpAttempt?.verifications[field];
    if (verification?.expireAt == null) return null;
    
    final now = DateTime.now();
    if (verification!.expireAt!.isBefore(now)) {
      return Duration.zero;
    }
    
    return verification.expireAt!.difference(now);
  }

  void reset() {
    _signUpAttempt = null;
  }
}