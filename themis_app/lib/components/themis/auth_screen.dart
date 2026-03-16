import 'package:flutter/material.dart';
import '../ui/primary_button.dart';
import '../ui/custom_text_field.dart';

class AuthScreen extends StatefulWidget {
  final Function(Map<String, String> user) onLogin;

  const AuthScreen({Key? key, required this.onLogin}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  String name = "";
  String email = "";
  String password = "";
  String role = "advogado";

  void handleSubmit() {
    final user = {
      'name': !isLogin ? name : 'Usuario',
      'email': email,
      'role': role,
    };
    widget.onLogin(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Ou usar Tb.slate.shade50
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
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
                  Text(
                    "Themis",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E1E2C), // Primary Color
                    ),
                  ),
                  const Text(
                    "Análise inteligente de precedentes",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // Tabs
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
                            onTap: () => setState(() => isLogin = true),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isLogin
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isLogin
                                    ? [
                                        const BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: const Text(
                                "Entrar",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => isLogin = false),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isLogin
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: !isLogin
                                    ? [
                                        const BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: const Text(
                                "Cadastrar",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Refatorado em Componentes
                  if (!isLogin) ...[
                    CustomTextField(
                      label: "Nome completo",
                      hintText: "Dr. Joao Silva",
                      onChanged: (v) => name = v,
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    label: "E-mail",
                    hintText: "joao@escritorio.com",
                    onChanged: (v) => email = v,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: "Senha",
                    hintText: "••••••••",
                    obscureText: true,
                    onChanged: (v) => password = v,
                  ),
                  const SizedBox(height: 24),

                  // Botao refatorado
                  PrimaryButton(
                    text: isLogin ? "Entrar" : "Criar conta",
                    onPressed: handleSubmit,
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
