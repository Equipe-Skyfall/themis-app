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
import 'components/pages/case_history_page.dart';
import 'components/pages/petition_result_page.dart';
import 'lib/models.dart';
import 'lib/profile_mode.dart';

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
    final isInCaseHistory = useState(false);

    // Inicia na aba Advogado por padrão
    final profileMode = useState<ProfileMode>(ProfileMode.lawyer);

    final selectedCase = useState<CaseHistory?>(null);
    final selectedPrecedents = useState<List<Precedent>?>(null);
    final selectedSummary = useState<String?>(null);
    final selectedAnalysisData = useState<Map<String, dynamic>?>(null);

    // Resultado de geração de petição (Frente 1 — advogado)
    final petitionText = useState<String?>(null);
    final petitionCaseDescription = useState<String?>(null);
    final petitionPrecedents = useState<List<Precedent>>([]);
    final petitionWeakPrecedents = useState(false);

    // ── Auth ─────────────────────────────────────────────────────────────────
    if (auth.session == null) {
      return AuthPage(onLogin: auth.login, onRegister: auth.register);
    }

    // ── Configurações (sem navbar) ────────────────────────────────────────────
    if (isInSettings.value) {
      return SettingsScreen(
        onBack: () => isInSettings.value = false,
        session: auth.session,
        onProfileUpdated: auth.updateSession,
        onForceLogout: () async {
          isInSettings.value = false;
          await auth.logout();
        },
      );
    }

    // ── Upload/análise (sem navbar) ───────────────────────────────────────────
    if (isInUpload.value) {
      return UploadScreen(
        token: auth.session?.token,
        profileMode: profileMode.value,
        onBack: () => isInUpload.value = false,
        onAnalysisReady: (caseTitle, precedents, summary, analysisData) {
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
          selectedAnalysisData.value = analysisData;
          isInUpload.value = false;
        },
        onPetitionGenerated: (text, description, precedents, weakPrecedents) {
          petitionText.value = text;
          petitionCaseDescription.value = description;
          petitionPrecedents.value = precedents;
          petitionWeakPrecedents.value = weakPrecedents;
          isInUpload.value = false;
        },
      );
    }

    // ── Resultado de petição gerada (Frente 1 — sem navbar) ──────────────────
    if (petitionText.value != null) {
      return PetitionResultPage(
        initialPetitionText: petitionText.value!,
        caseDescription: petitionCaseDescription.value ?? '',
        initialPrecedents: petitionPrecedents.value,
        initialWeakPrecedents: petitionWeakPrecedents.value,
        token: auth.session?.token,
        onBack: () {
          petitionText.value = null;
          petitionCaseDescription.value = null;
          petitionPrecedents.value = [];
          petitionWeakPrecedents.value = false;
        },
      );
    }

    // ── Histórico de Processos (Frente 2) ─────────────────────────────────────
    if (isInCaseHistory.value) {
      return CaseHistoryPage(
        token: auth.session?.token,
        onBack: () => isInCaseHistory.value = false,
        onSelectHistory: (entry) {
          selectedCase.value = CaseHistory(
            id: entry.id,
            title: entry.filename,
            date:
                '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year}',
            status: 'completed',
            matchCount: entry.precedents.length,
          );
          selectedPrecedents.value = entry.precedents;
          selectedSummary.value = entry.summary;
          selectedAnalysisData.value = {
            if (entry.minuta != null) 'minuta': entry.minuta,
            if (entry.petitionSummary != null) 'petition_summary': entry.petitionSummary,
            if (entry.documents.isNotEmpty) 'documents': entry.documents,
          };
          isInCaseHistory.value = false;
        },
      );
    }

    // ── Resultados (sem navbar) ───────────────────────────────────────────────
    if (selectedCase.value != null) {
      return ResultsPage(
        case_: selectedCase.value!,
        precedents: selectedPrecedents.value ?? [],
        summary: selectedSummary.value,
        analysisData: selectedAnalysisData.value,
        onBack: () {
          selectedCase.value = null;
          selectedPrecedents.value = null;
          selectedSummary.value = null;
          selectedAnalysisData.value = null;
        },
      );
    }

    // ── Dashboard com BottomNav ───────────────────────────────────────────────
    return DashboardPage(
      userName: auth.session?.user.username,
      token: auth.session?.token,
      profileMode: profileMode.value,
      onProfileModeChanged: (mode) => profileMode.value = mode,
      // FAB "+" abre o upload no contexto do perfil ativo
      onNewAnalysis: () => isInUpload.value = true,
      onLogout: () => auth.logout(),
      onOpenSettings: () => isInSettings.value = true,
      onSelectHistory: (entry) {
        // Frente 1 (Advogado): abre PetitionResultPage com o texto da petição
        if (entry.petitionText != null && entry.petitionText!.isNotEmpty) {
          petitionText.value = entry.petitionText;
          petitionCaseDescription.value = entry.caseDescription ?? '';
          petitionPrecedents.value = entry.precedents;
          petitionWeakPrecedents.value = entry.weakPrecedents;
          return;
        }
        // Frente 2 (Juiz): abre ResultsPage com precedentes e minuta
        selectedCase.value = CaseHistory(
          id: entry.id,
          title: entry.filename,
          date:
              '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year}',
          status: 'completed',
          matchCount: entry.precedents.length,
        );
        selectedPrecedents.value = entry.precedents;
        selectedSummary.value = entry.summary;
        selectedAnalysisData.value = {
          if (entry.minuta != null) 'minuta': entry.minuta,
          if (entry.petitionSummary != null) 'petition_summary': entry.petitionSummary,
          if (entry.documents.isNotEmpty) 'documents': entry.documents,
        };
      },
      // Abre o histórico completo de processos (Frente 2)
      onViewAllHistory: profileMode.value == ProfileMode.judge
          ? () => isInCaseHistory.value = true
          : null,
    );
  }
}
