import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'hooks/use_auth_controller.dart';
import 'components/pages/auth_page.dart';
import 'components/pages/dashboard_page.dart';
import 'components/pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
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

class AppController extends HookWidget {
  const AppController({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = useAuthController();
    final isInSettings = useState(false);

    if (auth.session == null) {
      return AuthPage(onLogin: auth.login, onRegister: auth.register);
    }

    if (isInSettings.value) {
      return SettingsPage(
        onBack: () {
          isInSettings.value = false;
        },
      );
    }

    return DashboardPage(
      userName: auth.session?.user.username,
      onLogout: () {
        auth.logout();
      },
      onOpenSettings: () {
        isInSettings.value = true;
      },
      onNewAnalysis: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nova Análise iniciada')));
      },
    );
  }
}
