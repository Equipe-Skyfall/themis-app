import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../ui/app_bar.dart';
import '../../data/auth/auth_api_service.dart';
import '../../hooks/use_settings_controller.dart';

class SettingsScreen extends HookWidget {
  final VoidCallback onBack;
  final AuthSession? session;
  final Function(AuthSession)? onProfileUpdated;
  final Future<void> Function()? onAccountDeleted;

  const SettingsScreen({
    Key? key,
    required this.onBack,
    required this.session,
    this.onProfileUpdated,
    this.onAccountDeleted,
  }) : super(key: key);

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

    useEffect(() {
      if (session != null) {
        usernameController.text = session!.user.username;
        emailController.text = session!.user.email;
      }
      return null;
    }, [session]);

    Future<void> handleSavePersonalData() async {
      final error = await settings.updateProfile(
        username: usernameController.text,
        email: emailController.text,
      );

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
        }

        successMessage.value = 'Dados pessoais atualizados com sucesso!';
        errorMessage.value = null;
        Future.delayed(const Duration(seconds: 3), () {
          successMessage.value = null;
        });
      } else {
        errorMessage.value = error;
        successMessage.value = null;
      }
    }

    // Callback para alterar senha
    Future<void> handleChangePassword() async {
      if (currentPasswordController.text.trim().isEmpty) {
        errorMessage.value = 'Informe a senha atual.';
        return;
      }

      if (newPasswordController.text != confirmPasswordController.text) {
        errorMessage.value = 'As senhas não conferem.';
        return;
      }

      if (newPasswordController.text.length < 6) {
        errorMessage.value = 'A nova senha deve ter no mínimo 6 caracteres.';
        return;
      }

      final error = await settings.changePassword(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
      );

      if (error == null) {
        successMessage.value = 'Senha alterada com sucesso!';
        errorMessage.value = null;
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();
        Future.delayed(const Duration(seconds: 3), () {
          successMessage.value = null;
        });
      } else {
        errorMessage.value = error;
        successMessage.value = null;
      }
    }

    // Callback para deletar conta
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
          }
        } else {
          errorMessage.value = error;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: CustomAppBar(
        title: 'Configurações',
        onBack: onBack,
        showSettings: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 8),

            if (errorMessage.value != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Text(
                  errorMessage.value!,
                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                ),
              ),

            if (successMessage.value != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(
                  successMessage.value!,
                  style: TextStyle(color: Colors.green[700], fontSize: 14),
                ),
              ),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF1E1E2C),
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    session?.user.username ?? 'Usuário',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionCard(
              icon: Icons.person_outline,
              title: 'Dados Pessoais',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nome de usuário',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EditableField(
                    controller: usernameController,
                    hintText: 'Seu nome de usuário',
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Email',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EditableField(
                    controller: emailController,
                    hintText: 'Seu email',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: settings.isLoading
                          ? null
                          : handleSavePersonalData,
                      icon: const Icon(Icons.check, size: 18),
                      label: settings.isLoading
                          ? const Text('Salvando...')
                          : const Text('Atualizar Dados'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color.fromARGB(
                          255,
                          20,
                          20,
                          26,
                        ).withOpacity(0.8),
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
            _SectionCard(
              icon: Icons.lock_outline,
              title: 'Alterar Senha',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Senha atual',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EditableField(
                    controller: currentPasswordController,
                    hintText: 'Digite sua senha atual',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nova senha',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EditableField(
                    controller: newPasswordController,
                    hintText: 'Mínimo 6 caracteres',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Confirmar nova senha',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EditableField(
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
                        backgroundColor: const Color.fromARGB(
                          255,
                          26,
                          26,
                          32,
                        ).withOpacity(0.8),
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
}
