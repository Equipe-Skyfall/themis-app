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
<<<<<<< settingsPage
  final Future<void> Function()? onForceLogout;
=======
  final Future<void> Function()? onAccountDeleted;
>>>>>>> dev

  const SettingsScreen({
    super.key,
    required this.onBack,
    required this.session,
    this.onProfileUpdated,
<<<<<<< settingsPage
    this.onForceLogout,
  });
=======
    this.onAccountDeleted,
  }) : super(key: key);
>>>>>>> dev

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
<<<<<<< settingsPage
    final successMessageTimer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        successMessageTimer.value?.cancel();
      };
    }, const []);
=======
>>>>>>> dev

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

<<<<<<< settingsPage
      if (!context.mounted) {
        return;
      }

      if (result.isSuccess) {
        if (result.updatedSession != null) {
          onProfileUpdated?.call(result.updatedSession!);
=======
      if (error == null) {
        if (session != null) {
          final updatedUser = AuthUser(
            id: session!.user.id,
            email: emailController.text,
            username: usernameController.text,
            role: session!.user.role,
          );
          final updatedSession = AuthSession(
            user: updatedUser,
            token: session!.token,
          );
          onProfileUpdated?.call(updatedSession);
>>>>>>> dev
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

<<<<<<< settingsPage
=======
    // Callback para alterar senha
>>>>>>> dev
    Future<void> handleChangePassword() async {
      if (currentPasswordController.text.trim().isEmpty) {
        errorMessage.value = 'Informe a senha atual.';
        return;
      }

      if (newPasswordController.text != confirmPasswordController.text) {
        errorMessage.value = 'As senhas nao conferem.';
        return;
      }

      if (newPasswordController.text.length < 6) {
        errorMessage.value = 'A nova senha deve ter no minimo 6 caracteres.';
        return;
      }

<<<<<<< settingsPage
      final result = await settings.changePassword(
=======
      final error = await settings.changePassword(
>>>>>>> dev
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
      );

<<<<<<< settingsPage
      if (!context.mounted) {
        return;
      }

      if (result.isSuccess) {
=======
      if (error == null) {
        successMessage.value = 'Senha alterada com sucesso!';
        errorMessage.value = null;
>>>>>>> dev
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

<<<<<<< settingsPage
=======
    // Callback para deletar conta
>>>>>>> dev
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
<<<<<<< settingsPage
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
=======
        final error = await settings.deleteAccount();
        if (error == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Conta deletada com sucesso')),
            );
          }

          if (onAccountDeleted != null) {
            await onAccountDeleted!();
          } else {
            onBack();
>>>>>>> dev
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
<<<<<<< settingsPage
=======

>>>>>>> dev
            if (errorMessage.value != null)
              SettingsFeedbackBanner(
                message: errorMessage.value!,
                isError: true,
              ),
<<<<<<< settingsPage
=======

>>>>>>> dev
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
<<<<<<< settingsPage
                  const SettingsSectionTitle(text: 'Email'),
=======

                  const Text(
                    'Email',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
>>>>>>> dev
                  const SizedBox(height: 8),
                  SettingsEditableField(
                    controller: emailController,
                    hintText: 'Seu email',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
<<<<<<< settingsPage
                      onPressed:
                          settings.isLoading ? null : handleSavePersonalData,
=======
                      onPressed: settings.isLoading
                          ? null
                          : handleSavePersonalData,
>>>>>>> dev
                      icon: const Icon(Icons.check, size: 18),
                      label: settings.isLoading
                          ? const Text('Salvando...')
                          : const Text('Atualizar Dados'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
<<<<<<< settingsPage
                        backgroundColor:
                            const Color.fromARGB(255, 20, 20, 26).withOpacity(0.8),
=======
                        backgroundColor: const Color.fromARGB(
                          255,
                          20,
                          20,
                          26,
                        ).withOpacity(0.8),
>>>>>>> dev
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
                      onPressed: settings.isLoading
                          ? null
                          : handleChangePassword,
                      icon: const Icon(Icons.check, size: 18),
                      label: settings.isLoading
                          ? const Text('Atualizando...')
                          : const Text('Atualizar Senha'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
<<<<<<< settingsPage
                        backgroundColor:
                            const Color.fromARGB(255, 26, 26, 32).withOpacity(0.8),
=======
                        backgroundColor: const Color.fromARGB(
                          255,
                          26,
                          26,
                          32,
                        ).withOpacity(0.8),
>>>>>>> dev
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
<<<<<<< settingsPage
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
=======
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF2B8B5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Color(0xFFD94841),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Zona de Perigo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD94841),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ao excluir sua conta, todos os seus dados serão permanentemente removidos. Esta ação não pode ser desfeita.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 18,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: settings.isLoading
                          ? null
                          : handleDeleteAccount,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        side: const BorderSide(color: Color(0xFFF2B8B5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        settings.isLoading
                            ? 'Deletando...'
                            : 'Excluir Minha Conta',
                        style: const TextStyle(
                          color: Color(0xFFD94841),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1E2D9C), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1E1E2C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool obscureText;

  const _EditableField({
    this.controller,
    required this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 18,
          color: Color.fromARGB(255, 30, 33, 36),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E2D9C), width: 1.4),
        ),
      ),
    );
  }
>>>>>>> dev
}
