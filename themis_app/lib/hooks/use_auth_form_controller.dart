import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

typedef LoginHandler = Future<String?> Function(String email, String password);
typedef RegisterHandler = Future<String?> Function({
  required String username,
  required String email,
  required String password,
});

enum AuthSubmitResult { successLogin, successRegister, failure }

class AuthFormController {
  final bool isLogin;
  final bool isSubmitting;
  final String? errorMessage;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback showLogin;
  final VoidCallback showRegister;
  final Future<AuthSubmitResult> Function() submit;

  const AuthFormController({
    required this.isLogin,
    required this.isSubmitting,
    required this.errorMessage,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.showLogin,
    required this.showRegister,
    required this.submit,
  });
}

AuthFormController useAuthFormController({
  required LoginHandler onLogin,
  required RegisterHandler onRegister,
}) {
  final isLogin = useState(true);
  final isSubmitting = useState(false);
  final errorMessage = useState<String?>(null);

  final nameController = useTextEditingController();
  final emailController = useTextEditingController();
  final passwordController = useTextEditingController();

  void showLogin() {
    isLogin.value = true;
    errorMessage.value = null;
  }

  void showRegister() {
    isLogin.value = false;
    errorMessage.value = null;
  }

  Future<AuthSubmitResult> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Preencha e-mail e senha.';
      return AuthSubmitResult.failure;
    }

    if (!isLogin.value && name.isEmpty) {
      errorMessage.value = 'Informe seu nome de usuario.';
      return AuthSubmitResult.failure;
    }

    errorMessage.value = null;
    isSubmitting.value = true;

    String? resultError;
    if (isLogin.value) {
      resultError = await onLogin(email, password);
    } else {
      resultError = await onRegister(
        username: name,
        email: email,
        password: password,
      );
    }

    isSubmitting.value = false;

    if (resultError != null && resultError.isNotEmpty) {
      errorMessage.value = resultError;
      return AuthSubmitResult.failure;
    }

    return isLogin.value
        ? AuthSubmitResult.successLogin
        : AuthSubmitResult.successRegister;
  }

  return AuthFormController(
    isLogin: isLogin.value,
    isSubmitting: isSubmitting.value,
    errorMessage: errorMessage.value,
    nameController: nameController,
    emailController: emailController,
    passwordController: passwordController,
    showLogin: showLogin,
    showRegister: showRegister,
    submit: submit,
  );
}
