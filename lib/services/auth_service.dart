enum AccountType { family, personal }

/// Account operations the sign-in flow needs from the backend.
///
/// The app uses [authService]; swap [MockAuthService] for a real
/// implementation once the API is available.
abstract interface class AuthService {
  /// Whether an account already exists for [phoneNumber] (E.164, e.g.
  /// "+97455555555").
  Future<bool> isRegistered(String phoneNumber);

  /// Creates an account for [phoneNumber].
  Future<void> createAccount({
    required String phoneNumber,
    required AccountType type,
  });
}

/// In-memory stand-in for the backend.
///
/// "+974 5555 5555" counts as an existing account; any other number is new
/// until an account is created for it (for the rest of the session).
class MockAuthService implements AuthService {
  final _registered = <String>{'+97455555555'};

  static const _latency = Duration(milliseconds: 900);

  @override
  Future<bool> isRegistered(String phoneNumber) async {
    await Future<void>.delayed(_latency);
    return _registered.contains(phoneNumber);
  }

  @override
  Future<void> createAccount({
    required String phoneNumber,
    required AccountType type,
  }) async {
    await Future<void>.delayed(_latency);
    _registered.add(phoneNumber);
  }
}

final AuthService authService = MockAuthService();
