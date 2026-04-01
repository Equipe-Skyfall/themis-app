import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/auth/auth_api_service.dart';

class AuthController {
  final AuthSession? session;
  final Future<String?> Function(String email, String password) login;
  final Future<String?> Function({
    required String username,
    required String email,
    required String password,
  }) register;
  final Future<void> Function() logout;
  final void Function(AuthSession nextSession) updateSession;

  const AuthController({
    required this.session,
    required this.login,
    required this.register,
    required this.logout,
    required this.updateSession,
  });
}

AuthController useAuthController({AuthApiService? service}) {
  final authService = useMemoized(() => service ?? AuthApiService(), [service]);
  final session = useState<AuthSession?>(null);

  Future<String?> login(String email, String password) async {
    try {
      final nextSession = await authService.login(email: email, password: password);
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

  Future<void> logout() async {
    final token = session.value?.token;

    try {
      await authService.logout(token: token);
    } finally {
      session.value = null;
    }
  }

  void updateSession(AuthSession nextSession) {
    session.value = nextSession;
  }

  return AuthController(
    session: session.value,
    login: login,
    register: register,
    logout: logout,
    updateSession: updateSession,
  );
}
