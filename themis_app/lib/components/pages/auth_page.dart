import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../ui/custom_text_field.dart';
import '../ui/primary_button.dart';
import '../../hooks/use_auth_form_controller.dart';

class AuthPage extends HookWidget {
  final LoginHandler onLogin;
  final RegisterHandler onRegister;

  const AuthPage({super.key, required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final authForm = useAuthFormController(
      onLogin: onLogin,
      onRegister: onRegister,
    );

    Future<void> onSubmitPressed() async {
      final result = await authForm.submit();
      if (result == AuthSubmitResult.successRegister && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada com sucesso.')),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 144,
                    height: 144,
                    child: Center(
                      child: Image.asset(
                        'lib/assets/logo_transparente.png',
                        width: 144,
                        height: 144,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 144, height: 144),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Themis',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2C),
                    ),
                  ),
                  const Text(
                    'Analise inteligente de precedentes',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: authForm.showLogin,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: authForm.isLogin
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: authForm.isLogin
                                    ? const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : const [],
                              ),
                              child: const Text(
                                'Entrar',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: authForm.showRegister,
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !authForm.isLogin
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: !authForm.isLogin
                                    ? const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : const [],
                              ),
                              child: const Text(
                                'Cadastrar',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!authForm.isLogin) ...[
                    CustomTextField(
                      label: 'Nome de usuario',
                      hintText: 'Insira seu nome de usuario aqui',
                      controller: authForm.nameController,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                  ],
                  CustomTextField(
                    label: 'E-mail',
                    hintText: 'Insira seu email aqui',
                    controller: authForm.emailController,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Senha',
                    hintText: '••••••••',
                    obscureText: true,
                    controller: authForm.passwordController,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (authForm.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      authForm.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFD94841),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: authForm.isSubmitting
                        ? 'Carregando...'
                        : (authForm.isLogin ? 'Entrar' : 'Criar conta'),
                    onPressed: authForm.isSubmitting ? null : onSubmitPressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
