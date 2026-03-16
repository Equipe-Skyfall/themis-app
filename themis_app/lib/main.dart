import 'package:flutter/material.dart';
import 'components/themis/auth_screen.dart';
import 'components/themis/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Themis App',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E1E2C),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E1E2C)),
        useMaterial3: true,
      ),
      home: const AppController(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppController extends StatefulWidget {
  const AppController({super.key});

  @override
  State<AppController> createState() => _AppControllerState();
}

class _AppControllerState extends State<AppController> {
  bool isLoggedIn = false;
  Map<String, String>? currentUser;

  void handleLogin(Map<String, String> user) {
    setState(() {
      currentUser = user;
      isLoggedIn = true;
    });
  }

  void handleLogout() {
    setState(() {
      currentUser = null;
      isLoggedIn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return AuthScreen(onLogin: handleLogin);
    }

    return DashboardScreen(
      userName: currentUser?['name'],
      onLogout: handleLogout,
      onNewAnalysis: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nova Análise iniciada')));
      },
    );
  }
}
