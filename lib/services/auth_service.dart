/// Simple local auth — stores the logged-in username in memory.
/// No Firebase Auth needed; credentials are hardcoded per spec.
class AuthService {
  static final AuthService _i = AuthService._();
  factory AuthService() => _i;
  AuthService._();

  String? _currentUser;

  String? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  bool login(String username, String password) {
    if (username == 'Abdulaziz' && password == 'Aziz@123') {
      _currentUser = username;
      return true;
    }
    return false;
  }

  void logout() => _currentUser = null;
}
