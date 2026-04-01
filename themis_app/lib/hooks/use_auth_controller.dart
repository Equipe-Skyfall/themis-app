import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/auth/auth_api_service.dart';
import '../data/auth/auth_secure_storage.dart';

class AuthController {
  final AuthSession? session;
  final Future<String?> Function(String email, String password) login;
  final Future<String?> Function({
    required String username,
    required String email,
    required String password,
  })
  register;
  final void Function(AuthSession nextSession) setSession;
  final Future<void> Function() clearSession;
  final Future<void> Function() logout;
  final void Function(AuthSession nextSession) updateSession;

  const AuthController({
    required this.session,
    required this.login,
    required this.register,
    required this.setSession,
    required this.clearSession,
    required this.logout,
    required this.updateSession,
  });
}

AuthController useAuthController({AuthApiService? service}) {
  final authService = useMemoized(() => service ?? AuthApiService(), [service]);
  final secureStorage = useMemoized(() => AuthSecureStorage());
  final session = useState<AuthSession?>(null);

  useEffect(() {
    var isDisposed = false;

    Future<void> restoreSession() async {
      final token = await secureStorage.readToken();
      if (token == null || token.isEmpty) {
        return;
      }

      try {
        final user = await authService.getProfile(token: token);
        if (!isDisposed) {
          session.value = AuthSession(user: user, token: token);
        }
      } catch (_) {
        await secureStorage.deleteToken();
      }
    }

    restoreSession();

    return () {
      isDisposed = true;
    };
  }, [authService, secureStorage]);

  Future<String?> login(String email, String password) async {
    try {
      final nextSession = await authService.login(
        email: email,
        password: password,
      );
      if (nextSession.token != null && nextSession.token!.isNotEmpty) {
        await secureStorage.saveToken(nextSession.token!);
      }
      session.value = nextSession;
      return null;
    } on AuthApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nao foi possivel entrar agora. Tente novamente.';
    }
  }

  Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      await authService.registerUser(
        username: username,
        email: email,
        password: password,
      );
      return login(email, password);
    } on AuthApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nao foi possivel criar a conta agora. Tente novamente.';
    }
  }

  void setSession(AuthSession nextSession) {
    final token = nextSession.token;
    if (token != null && token.isNotEmpty) {
      secureStorage.saveToken(token);
    }
    session.value = nextSession;
  }

  Future<void> clearSession() async {
    await secureStorage.deleteToken();
    session.value = null;
  }

  Future<void> logout() async {
    final token = session.value?.token;

    try {
      await authService.logout(token: token);
    } finally {
      await clearSession();
    }
  }

  void updateSession(AuthSession nextSession) {
    session.value = nextSession;
  }

  return AuthController(
    session: session.value,
    login: login,
    register: register,
    setSession: setSession,
    clearSession: clearSession,
    logout: logout,
    updateSession: updateSession,
  );
}
