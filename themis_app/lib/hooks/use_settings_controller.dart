import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/auth/auth_api_service.dart';
import '../data/settings/settings_api_service.dart';

class SettingsController {
  final Future<String?> Function({
    required String username,
    required String email,
  }) updateProfile;
  final Future<String?> Function({
    required String currentPassword,
    required String newPassword,
  }) changePassword;
  final Future<String?> Function() deleteAccount;
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
}) {
  final settingsService =
      useMemoized(() => service ?? SettingsApiService(), [service]);
  final isLoading = useState(false);

  Future<String?> updateProfile({
    required String username,
    required String email,
  }) async {
    if (session == null || session.token == null || session.user.id.isEmpty) {
      return 'Sessao expirada. Faca login novamente.';
    }

    isLoading.value = true;
    try {
      await settingsService.updateUserProfile(
        token: session.token!,
        userId: session.user.id,
        username: username,
        email: email,
      );
      return null;
    } on SettingsApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nao foi possivel atualizar os dados. Tente novamente.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (session == null || session.token == null || session.user.id.isEmpty) {
      return 'Sessao expirada. Faca login novamente.';
    }

    isLoading.value = true;
    try {
      await settingsService.changePassword(
        token: session.token!,
        userId: session.user.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on SettingsApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nao foi possivel alterar a senha. Tente novamente.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> deleteAccount() async {
    if (session == null || session.token == null || session.user.id.isEmpty) {
      return 'Sessao expirada. Faca login novamente.';
    }

    isLoading.value = true;
    try {
      await settingsService.deleteAccount(
        token: session.token!,
        userId: session.user.id,
      );
      return null;
    } on SettingsApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Nao foi possivel deletar a conta. Tente novamente.';
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
