import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hooks/use_auth_controller.dart';
import 'components/pages/auth_page.dart';
import 'components/pages/dashboard_page.dart';
import 'components/pages/settings_page.dart';
import 'components/pages/results_page.dart';
import 'components/pages/upload_pdf_screen.dart';
import 'lib/models.dart';
import 'data/mock_data.dart';

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
        textTheme: GoogleFonts.poppinsTextTheme(),
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
    final isInUpload = useState(false);
    final selectedCase = useState<CaseHistory?>(null);
    final selectedPrecedents = useState<List<Precedent>?>(null);

    if (auth.session == null) {
      return AuthPage(onLogin: auth.login, onRegister: auth.register);
    }

    if (isInSettings.value) {
      return SettingsScreen(
        onBack: () {
          isInSettings.value = false;
        },
        session: auth.session,
<<<<<<< settingsPage
        onProfileUpdated: auth.updateSession,
        onForceLogout: () async {
          isInSettings.value = false;
          await auth.logout();
=======
        onProfileUpdated: (updatedSession) {
          auth.setSession(updatedSession);
        },
        onAccountDeleted: () async {
          await auth.clearSession();
          isInSettings.value = false;
        },
      );
    }

    if (isInUpload.value) {
      return UploadScreen(
        token: auth.session?.token,
        onBack: () {
          isInUpload.value = false;
        },
        onAnalysisReady: (caseTitle, precedents) {
          final now = DateTime.now();
          selectedCase.value = CaseHistory(
            id: 'analysis_${now.millisecondsSinceEpoch}',
            title: caseTitle,
            date: '${now.day}/${now.month}/${now.year}',
            status: 'completed',
            matchCount: precedents.length,
          );
          selectedPrecedents.value = precedents;
          isInUpload.value = false;
>>>>>>> dev
        },
      );
    }

    if (selectedCase.value != null) {
      final precedentsForCase = selectedPrecedents.value ?? mockPrecedents;
      return ResultsPage(
        case_: selectedCase.value!,
        precedents: precedentsForCase,
        onBack: () {
          selectedCase.value = null;
          selectedPrecedents.value = null;
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
        isInUpload.value = true;
      },
      onSelectCase: (caseItem) {
        if (caseItem.status == 'completed') {
          selectedCase.value = caseItem;
          selectedPrecedents.value = mockPrecedents;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Apenas análises concluídas podem ser visualizadas',
              ),
            ),
          );
        }
      },
    );
  }
}
