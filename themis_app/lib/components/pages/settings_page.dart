import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../data/auth/auth_api_service.dart';
import '../../hooks/use_settings_controller.dart';
import '../ui/app_bar.dart';
import '../ui/settings_widgets.dart';

class SettingsScreen extends HookWidget {
  final VoidCallback onBack;
  final AuthSession? session;
  final Function(AuthSession)? onProfileUpdated;
  final Future<void> Function()? onForceLogout;

  const SettingsScreen({
    super.key,
    required this.onBack,
    required this.session,
    this.onProfileUpdated,
    this.onForceLogout,
  });

  @override
  Widget build(BuildContext context) {
    final settings = useSettingsController(session: session);

    final usernameController = useTextEditingController();
    final emailController = useTextEditingController();

    final currentPasswordController = useTextEditingController();
    final newPasswordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();

    final successMessage = useState<String?>(null);
    final errorMessage = useState<String?>(null);
    final successMessageTimer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        successMessageTimer.value?.cancel();
      };
    }, const []);

    useEffect(() {
      if (session != null) {
        usernameController.text = _formatUsernameForDisplay(
          session!.user.username,
        );
        emailController.text = session!.user.email;
      }
      return null;
    }, [session]);

    Future<void> handleSavePersonalData() async {
      final result = await settings.updateProfile(
        username: usernameController.text,
        email: emailController.text,
      );

      if (!context.mounted) {
        return;
      }

      if (result.isSuccess) {
        if (result.updatedSession != null) {
          onProfileUpdated?.call(result.updatedSession!);
        }

        successMessage.value = 'Dados pessoais atualizados com sucesso!';
        errorMessage.value = null;
        successMessageTimer.value?.cancel();
        successMessageTimer.value = Timer(const Duration(seconds: 3), () {
          if (context.mounted) {
            successMessage.value = null;
          }
        });
      } else {
        errorMessage.value = result.error;
        successMessage.value = null;
      }
    }

    Future<void> handleChangePassword() async {
      if (newPasswordController.text != confirmPasswordController.text) {
        errorMessage.value = 'As senhas nao conferem.';
        return;
      }

      if (newPasswordController.text.length < 6) {
        errorMessage.value = 'A nova senha deve ter no minimo 6 caracteres.';
        return;
      }

      final result = await settings.changePassword(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
      );

      if (!context.mounted) {
        return;
      }

      if (result.isSuccess) {
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        if (result.shouldLogout && onForceLogout != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Senha alterada com sucesso. Faca login novamente.'),
            ),
          );
          await onForceLogout!.call();
          return;
        }

        successMessage.value = 'Senha alterada com sucesso!';
        errorMessage.value = null;
        successMessageTimer.value?.cancel();
        successMessageTimer.value = Timer(const Duration(seconds: 3), () {
          if (context.mounted) {
            successMessage.value = null;
          }
        });
      } else {
        errorMessage.value = result.error;
        successMessage.value = null;
      }
    }

    Future<void> handleDeleteAccount() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir Conta'),
          content: const Text(
            'Tem certeza que deseja excluir sua conta? Esta acao e permanente e nao pode ser desfeita.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final result = await settings.deleteAccount();
        if (!context.mounted) {
          return;
        }

        if (result.isSuccess) {
          if (result.shouldLogout && onForceLogout != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conta deletada com sucesso')),
            );
            await onForceLogout!.call();
            return;
          }

          onBack();
        } else {
          errorMessage.value = result.error;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: CustomAppBar(
        title: 'Configuracoes',
        onBack: onBack,
        showSettings: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),
            if (errorMessage.value != null)
              SettingsFeedbackBanner(
                message: errorMessage.value!,
                isError: true,
              ),
            if (successMessage.value != null)
              SettingsFeedbackBanner(
                message: successMessage.value!,
                isError: false,
              ),
            SettingsProfileHeader(
              username: _formatUsernameForDisplay(
                session?.user.username ?? 'Usuario',
              ),
            ),
            const SizedBox(height: 24),
            SettingsSectionCard(
              icon: Icons.person_outline,
              title: 'Dados Pessoais',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionTitle(text: 'Nome de usuario'),
                  const SizedBox(height: 8),
                  SettingsEditableField(
                    controller: usernameController,
                    hintText: 'Seu nome de usuario',
                  ),
                  const SizedBox(height: 12),
                  const SettingsSectionTitle(text: 'Email'),
                  const SizedBox(height: 8),
                  SettingsEditableField(
                    controller: emailController,
                    hintText: 'Seu email',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          settings.isLoading ? null : handleSavePersonalData,
                      icon: const Icon(Icons.check, size: 18),
                      label: settings.isLoading
                          ? const Text('Salvando...')
                          : const Text('Atualizar Dados'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor:
                            const Color.fromARGB(255, 20, 20, 26).withOpacity(0.8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsSectionCard(
              icon: Icons.lock_outline,
              title: 'Alterar Senha',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SettingsSectionTitle(text: 'Senha atual'),
                  const SizedBox(height: 8),
                  SettingsEditableField(
                    controller: currentPasswordController,
                    hintText: 'Digite sua senha atual',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  const SettingsSectionTitle(text: 'Nova senha'),
                  const SizedBox(height: 8),
                  SettingsEditableField(
                    controller: newPasswordController,
                    hintText: 'Minimo 6 caracteres',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  const SettingsSectionTitle(text: 'Confirmar nova senha'),
                  const SizedBox(height: 8),
                  SettingsEditableField(
                    controller: confirmPasswordController,
                    hintText: 'Repita a nova senha',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: settings.isLoading ? null : handleChangePassword,
                      icon: const Icon(Icons.check, size: 18),
                      label: settings.isLoading
                          ? const Text('Atualizando...')
                          : const Text('Atualizar Senha'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor:
                            const Color.fromARGB(255, 26, 26, 32).withOpacity(0.8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SettingsDangerZone(
              isLoading: settings.isLoading,
              onDelete: handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatUsernameForDisplay(String username) {
  return username.replaceAll('_', ' ').trim();
}
