import '../models/auth_attempt.dart';
import '../services/clerk_service.dart';

class SignInFlow {
  final ClerkService _service;
  SignInAttempt? _signInAttempt;

  SignInFlow(this._service);

  SignInAttempt? get currentAttempt => _signInAttempt;

  Future<SignInAttempt> create(String identifier) async {
    try {
      print('🔄 Creating sign-in attempt for: $identifier');
      
      final data = await _service.request(
        '/client/sign_ins',
        method: 'POST',
        body: {'identifier': identifier},
      );

      _signInAttempt = SignInAttempt.fromJson(data['response']);
      
      print('✅ Sign-in attempt created: ${_signInAttempt!.id}');
      print('📋 Supported factors: ${_signInAttempt!.supportedFirstFactors.map((f) => f.strategy).join(', ')}');
      
      return _signInAttempt!;
    } catch (e) {
      print('❌ Failed to create sign-in: $e');
      rethrow;
    }
  }

  Future<SignInAttempt> attemptPassword(String password) async {
    if (_signInAttempt == null) {
      throw Exception('Must create sign-in attempt first');
    }

    try {
      print('🔄 Attempting password authentication...');
      
      final data = await _service.request(
        '/client/sign_ins/${_signInAttempt!.id}/attempt_first_factor',
        method: 'POST',
        body: {
          'strategy': 'password',
          'password': password,
        },
      );

      _signInAttempt = SignInAttempt.fromJson(data['response']);
      
      if (_signInAttempt!.isComplete) {
        print('✅ Password authentication successful!');
        print('🎉 Session created: ${_signInAttempt!.createdSessionId}');
      } else {
        print('⚠️ Authentication incomplete: ${_signInAttempt!.status}');
      }

      return _signInAttempt!;
    } catch (e) {
      print('❌ Password authentication failed: $e');
      rethrow;
    }
  }

  Future<SignInAttempt> prepareEmailCode() async {
    if (_signInAttempt == null) {
      throw Exception('Must create sign-in attempt first');
    }

    // Find email code factor
    final emailFactor = _signInAttempt!.supportedFirstFactors
        .where((f) => f.isEmailCode)
        .firstOrNull;

    if (emailFactor == null) {
      throw Exception('Email code authentication not supported for this user');
    }

    try {
      print('📧 Preparing email code verification...');
      
      final data = await _service.request(
        '/client/sign_ins/${_signInAttempt!.id}/prepare_first_factor',
        method: 'POST',
        body: {
          'strategy': 'email_code',
          'email_address_id': emailFactor.emailAddressId!,
        },
      );

      _signInAttempt = SignInAttempt.fromJson(data['response']);
      
      print('✅ Email code sent successfully');
      
      return _signInAttempt!;
    } catch (e) {
      print('❌ Failed to prepare email code: $e');
      rethrow;
    }
  }

  Future<SignInAttempt> submitEmailCode(String code) async {
    if (_signInAttempt == null || _signInAttempt!.firstFactorVerification == null) {
      throw Exception('Must prepare email code first');
    }

    try {
      print('🔄 Verifying email code: $code');
      
      final data = await _service.request(
        '/client/sign_ins/${_signInAttempt!.id}/attempt_first_factor',
        method: 'POST',
        body: {
          'strategy': 'email_code',
          'code': code,
        },
      );

      _signInAttempt = SignInAttempt.fromJson(data['response']);

      if (_signInAttempt!.isComplete) {
        print('✅ Email code verification successful!');
        print('🎉 Session created: ${_signInAttempt!.createdSessionId}');
      } else {
        print('⚠️ Email code verification incomplete: ${_signInAttempt!.status}');
      }

      return _signInAttempt!;
    } catch (e) {
      print('❌ Email code verification failed: $e');
      rethrow;
    }
  }

  Future<SignInAttempt> preparePhoneCode() async {
    if (_signInAttempt == null) {
      throw Exception('Must create sign-in attempt first');
    }

    // Find phone code factor
    final phoneFactor = _signInAttempt!.supportedFirstFactors
        .where((f) => f.isPhoneCode)
        .firstOrNull;

    if (phoneFactor == null) {
      throw Exception('Phone code authentication not supported for this user');
    }

    try {
      print('📱 Preparing phone code verification...');
      
      final data = await _service.request(
        '/client/sign_ins/${_signInAttempt!.id}/prepare_first_factor',
        method: 'POST',
        body: {
          'strategy': 'phone_code',
          'phone_number_id': phoneFactor.phoneNumberId!,
        },
      );

      _signInAttempt = SignInAttempt.fromJson(data['response']);
      
      print('✅ Phone code sent successfully');
      
      return _signInAttempt!;
    } catch (e) {
      print('❌ Failed to prepare phone code: $e');
      rethrow;
    }
  }

  Future<SignInAttempt> submitPhoneCode(String code) async {
    if (_signInAttempt == null || _signInAttempt!.firstFactorVerification == null) {
      throw Exception('Must prepare phone code first');
    }

    try {
      print('🔄 Verifying phone code: $code');
      
      final data = await _service.request(
        '/client/sign_ins/${_signInAttempt!.id}/attempt_first_factor',
        method: 'POST',
        body: {
          'strategy': 'phone_code',
          'code': code,
        },
      );

      _signInAttempt = SignInAttempt.fromJson(data['response']);

      if (_signInAttempt!.isComplete) {
        print('✅ Phone code verification successful!');
        print('🎉 Session created: ${_signInAttempt!.createdSessionId}');
      } else {
        print('⚠️ Phone code verification incomplete: ${_signInAttempt!.status}');
      }

      return _signInAttempt!;
    } catch (e) {
      print('❌ Phone code verification failed: $e');
      rethrow;
    }
  }

  // Convenience methods
  Future<SignInAttempt> authenticateWithPassword(String identifier, String password) async {
    await create(identifier);
    return await attemptPassword(password);
  }

  Future<SignInAttempt> authenticateWithEmailCode(String identifier) async {
    await create(identifier);
    return await prepareEmailCode();
  }

  Future<SignInAttempt> authenticateWithPhoneCode(String identifier) async {
    await create(identifier);
    return await preparePhoneCode();
  }

  // Check supported authentication methods
  bool supportsPassword() {
    return _signInAttempt?.supportedFirstFactors.any((f) => f.isPassword) ?? false;
  }

  bool supportsEmailCode() {
    return _signInAttempt?.supportedFirstFactors.any((f) => f.isEmailCode) ?? false;
  }

  bool supportsPhoneCode() {
    return _signInAttempt?.supportedFirstFactors.any((f) => f.isPhoneCode) ?? false;
  }

  List<String> getSupportedStrategies() {
    return _signInAttempt?.supportedFirstFactors.map((f) => f.strategy).toList() ?? [];
  }

  void reset() {
    _signInAttempt = null;
  }
}

// Extension for better null safety
extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}