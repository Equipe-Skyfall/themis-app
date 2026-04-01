import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/auth/auth_api_service.dart';
import '../data/settings/settings_api_service.dart';

class SettingsOperationResult {
  final String? error;
  final AuthSession? updatedSession;
  final bool shouldLogout;

  const SettingsOperationResult({
    this.error,
    this.updatedSession,
    this.shouldLogout = false,
  });

  bool get isSuccess => error == null;
}

class SettingsController {
  final Future<SettingsOperationResult> Function({
    required String username,
    required String email,
  }) updateProfile;
  final Future<SettingsOperationResult> Function({
    required String currentPassword,
    required String newPassword,
  }) changePassword;
  final Future<SettingsOperationResult> Function() deleteAccount;
  final bool isLoading;

  const SettingsController({
    required this.updateProfile,
    required this.changePassword,
    required this.deleteAccount,
    required this.isLoading,
  });
}

SettingsController useSettingsController({
  required AuthSession? session,
  SettingsApiService? service,
  AuthApiService? authApiService,
}) {
  final settingsService =
      useMemoized(() => service ?? SettingsApiService(), [service]);
  final authService =
      useMemoized(() => authApiService ?? AuthApiService(), [authApiService]);
  final isLoading = useState(false);

  Future<SettingsOperationResult> updateProfile({
    required String username,
    required String email,
  }) async {
    if (session == null || session.token == null || session.user.id.isEmpty) {
      return const SettingsOperationResult(
        error: 'Sessao expirada. Faca login novamente.',
      );
    }

    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedUsername.isEmpty) {
      return const SettingsOperationResult(
        error: 'Informe seu nome de usuario.',
      );
    }

    if (!_isValidEmail(normalizedEmail)) {
      return const SettingsOperationResult(
        error: 'Email invalido. Verifique e tente novamente.',
      );
    }

    final currentDisplayUsername = _toDisplayUsername(session.user.username);
    final usernameChanged = normalizedUsername != currentDisplayUsername;
    final emailChanged =
        normalizedEmail != session.user.email.trim().toLowerCase();

    if (!usernameChanged && !emailChanged) {
      return const SettingsOperationResult(
        error: 'Nenhuma alteracao detectada para salvar.',
      );
    }

    isLoading.value = true;
    try {
      final apiUsername = _toApiUsername(normalizedUsername);

      await settingsService.updateUserProfile(
        token: session.token!,
        userId: session.user.id,
        username: apiUsername,
        email: normalizedEmail,
      );

      // Atualiza sessao local imediatamente para refletir no app,
      // mesmo que o endpoint de profile tenha consistencia eventual.
      final updatedSession = AuthSession(
        user: AuthUser(
          id: session.user.id,
          email: normalizedEmail,
          username: normalizedUsername,
          role: session.user.role,
        ),
        token: session.token,
      );

      return SettingsOperationResult(updatedSession: updatedSession);
    } on SettingsApiException catch (e) {
      return SettingsOperationResult(error: e.message);
    } catch (_) {
      return const SettingsOperationResult(
        error: 'Nao foi possivel atualizar os dados. Tente novamente.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<SettingsOperationResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (session == null || session.token == null || session.user.id.isEmpty) {
      return const SettingsOperationResult(
        error: 'Sessao expirada. Faca login novamente.',
      );
    }

    isLoading.value = true;
    try {
      try {
        await authService.login(
          email: session.user.email,
          password: currentPassword,
        );
      } on AuthApiException {
        return const SettingsOperationResult(error: 'Senha atual incorreta.');
      }

      await settingsService.changePassword(
        token: session.token!,
        userId: session.user.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      return const SettingsOperationResult(shouldLogout: true);
    } on SettingsApiException catch (e) {
      if (e.message.trim().toLowerCase() == 'something went wrong') {
        return const SettingsOperationResult(
          error:
              'Nao foi possivel alterar a senha. Verifique a senha atual e tente novamente.',
        );
      }
      return SettingsOperationResult(error: e.message);
    } catch (_) {
      return const SettingsOperationResult(
        error: 'Nao foi possivel alterar a senha. Tente novamente.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<SettingsOperationResult> deleteAccount() async {
    if (session == null || session.token == null || session.user.id.isEmpty) {
      return const SettingsOperationResult(
        error: 'Sessao expirada. Faca login novamente.',
      );
    }

    isLoading.value = true;
    try {
      await settingsService.deleteAccount(
        token: session.token!,
        userId: session.user.id,
      );
      return const SettingsOperationResult(shouldLogout: true);
    } on SettingsApiException catch (e) {
      return SettingsOperationResult(error: e.message);
    } catch (_) {
      return const SettingsOperationResult(
        error: 'Nao foi possivel deletar a conta. Tente novamente.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  return SettingsController(
    updateProfile: updateProfile,
    changePassword: changePassword,
    deleteAccount: deleteAccount,
    isLoading: isLoading.value,
  );
}

bool _isValidEmail(String email) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
}

String _toApiUsername(String username) {
  return username.trim();
}

String _toDisplayUsername(String username) {
  return username.replaceAll('_', ' ').trim();
}
