import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';

import 'hooks/use_auth_controller.dart';
import 'hooks/use_upload_petition_controller.dart' show toPrecedent;
import 'components/pages/auth_page.dart';
import 'components/pages/dashboard_page.dart';
import 'components/pages/settings_page.dart';
import 'components/pages/results_page.dart';
import 'components/pages/upload_pdf_screen.dart';
import 'components/pages/case_history_page.dart';
import 'components/pages/petition_result_page.dart';
import 'data/petition/case_analysis_api_service.dart';
import 'lib/models.dart';
import 'lib/profile_mode.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

    // ── Análise em background (Frente 2 — Juiz) ──────────────────────────────
    final judgeService = useMemoized(() => CaseAnalysisApiService());
    final isAnalyzing = useState(false);
    final analysisFileName = useState<String?>(null);
    final analysisError = useState<String?>(null);

    // ── Auth ─────────────────────────────────────────────────────────────────
    if (auth.session == null) {
      return AuthPage(onLogin: auth.login, onRegister: auth.register);
    }

    void applyAnalysisResult(Map<String, dynamic> response, String fileName) {
      final rawList = response['results'];
      final rawResults = (rawList is List)
          ? rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final precedents = rawResults.map(toPrecedent).toList();
      final summary = response['summary'] as String?;
      final data = response['analysis_data'] as Map<String, dynamic>?;

      final now = DateTime.now();
      selectedCase.value = CaseHistory(
        id: 'analysis_${now.millisecondsSinceEpoch}',
        title: 'Processo - $fileName',
        date: '${now.day}/${now.month}/${now.year}',
        status: 'completed',
        matchCount: precedents.length,
      );
      selectedPrecedents.value = precedents;
      selectedSummary.value = summary;
      selectedAnalysisData.value = data;
    }

    void startBackgroundAnalysis(
        String jobId, String fileName, int candidates) {
      isAnalyzing.value = true;
      analysisFileName.value = fileName;
      isInUpload.value = false;

      judgeService
          .fetchAnalysisResult(auth.session?.token ?? '', jobId, candidates)
          .then((response) {
        isAnalyzing.value = false;
        analysisFileName.value = null;
        applyAnalysisResult(response, fileName);
      }).catchError((e) {
        isAnalyzing.value = false;
        analysisFileName.value = null;
        analysisError.value = e is CaseAnalysisApiException
            ? e.message
            : 'Erro ao analisar processo. Tente novamente.';
      });
    }

    final bool hasSubPage = isInSettings.value ||
        isInUpload.value ||
        isInCaseHistory.value ||
        selectedCase.value != null ||
        petitionText.value != null;

    Widget body;

    // ── Configurações (sem navbar) ────────────────────────────────────────────
    if (isInSettings.value) {
      body = SettingsScreen(
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
    else if (isInUpload.value) {
      body = UploadScreen(
        token: auth.session?.token,
        profileMode: profileMode.value,
        onBack: () => isInUpload.value = false,
        onAnalysisJobStarted: startBackgroundAnalysis,
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
    else if (petitionText.value != null) {
      body = PetitionResultPage(
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
    else if (isInCaseHistory.value) {
      body = CaseHistoryPage(
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
            if (entry.petitionSummary != null)
              'petition_summary': entry.petitionSummary,
            if (entry.documents.isNotEmpty) 'documents': entry.documents,
          };
          isInCaseHistory.value = false;
        },
      );
    }

    // ── Resultados (sem navbar) ───────────────────────────────────────────────
    else if (selectedCase.value != null) {
      body = ResultsPage(
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
    else {
      body = DashboardPage(
        userName: auth.session?.user.username,
        token: auth.session?.token,
        profileMode: profileMode.value,
        onProfileModeChanged: (mode) => profileMode.value = mode,
        onNewAnalysis: () => isInUpload.value = true,
        onLogout: () => auth.logout(),
        onOpenSettings: () => isInSettings.value = true,
        isAnalyzing: isAnalyzing.value,
        analysisFileName: analysisFileName.value,
        analysisError: analysisError.value,
        onAnalysisErrorDismissed: () => analysisError.value = null,
        onSelectHistory: (entry) {
          if (entry.petitionText != null && entry.petitionText!.isNotEmpty) {
            petitionText.value = entry.petitionText;
            petitionCaseDescription.value = entry.caseDescription ?? '';
            petitionPrecedents.value = entry.precedents;
            petitionWeakPrecedents.value = entry.weakPrecedents;
            return;
          }
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
            if (entry.petitionSummary != null)
              'petition_summary': entry.petitionSummary,
            if (entry.documents.isNotEmpty) 'documents': entry.documents,
          };
        },
        onViewAllHistory: profileMode.value == ProfileMode.judge
            ? () => isInCaseHistory.value = true
            : null,
      );
    }

    return PopScope(
      canPop: !hasSubPage,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        if (isInSettings.value) {
          isInSettings.value = false;
        } else if (isInUpload.value) {
          isInUpload.value = false;
        } else if (petitionText.value != null) {
          petitionText.value = null;
          petitionCaseDescription.value = null;
          petitionPrecedents.value = [];
          petitionWeakPrecedents.value = false;
        } else if (isInCaseHistory.value) {
          isInCaseHistory.value = false;
        } else if (selectedCase.value != null) {
          selectedCase.value = null;
          selectedPrecedents.value = null;
          selectedSummary.value = null;
          selectedAnalysisData.value = null;
        }
      },
      child: body,
    );
  }
}

