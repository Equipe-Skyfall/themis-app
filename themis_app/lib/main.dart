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
    final selectedSummary = useState<String?>(null);

    if (auth.session == null) {
      return AuthPage(onLogin: auth.login, onRegister: auth.register);
    }

    if (isInSettings.value) {
      return SettingsScreen(
        onBack: () {
          isInSettings.value = false;
        },
        session: auth.session,
        onProfileUpdated: auth.updateSession,
        onForceLogout: () async {
          isInSettings.value = false;
          await auth.logout();
        },
      );
    }

    if (isInUpload.value) {
      return UploadScreen(
        token: auth.session?.token,
        onBack: () {
          isInUpload.value = false;
        },
        onAnalysisReady: (caseTitle, precedents, summary) {
          final now = DateTime.now();
          selectedCase.value = CaseHistory(
            id: 'analysis_${now.millisecondsSinceEpoch}',
            title: caseTitle,
            date: '${now.day}/${now.month}/${now.year}',
            status: 'completed',
            matchCount: precedents.length,
          );
          selectedPrecedents.value = precedents;
          selectedSummary.value = summary;
          isInUpload.value = false;
        },
      );
    }

    if (selectedCase.value != null) {
      return ResultsPage(
        case_: selectedCase.value!,
        precedents: selectedPrecedents.value ?? [],
        summary: selectedSummary.value,
        onBack: () {
          selectedCase.value = null;
          selectedPrecedents.value = null;
          selectedSummary.value = null;
        },
      );
    }

    return DashboardPage(
      userName: auth.session?.user.username,
      token: auth.session?.token,
      onLogout: () {
        auth.logout();
      },
      onOpenSettings: () {
        isInSettings.value = true;
      },
      onNewAnalysis: () {
        isInUpload.value = true;
      },
      onSelectHistory: (entry) {
        selectedCase.value = CaseHistory(
          id: entry.id,
          title: entry.filename,
          date: '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year}',
          status: 'completed',
          matchCount: entry.precedents.length,
        );
        selectedPrecedents.value = entry.precedents;
        selectedSummary.value = entry.summary;
      },
    );
  }
}
