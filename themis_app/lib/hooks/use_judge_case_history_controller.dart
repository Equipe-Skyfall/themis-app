// themis_app/lib/hooks/use_judge_case_history_controller.dart
import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/petition/case_analysis_api_service.dart';
import '../lib/models.dart';

class JudgeCaseHistoryController {
  final List<HistoryEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() refresh;

  const JudgeCaseHistoryController({
    required this.entries,
    required this.isLoading,
    required this.errorMessage,
    required this.refresh,
  });
}

JudgeCaseHistoryController useJudgeCaseHistoryController({
  required String? token,
  CaseAnalysisApiService? service,
}) {
  final caseAnalysisService = useMemoized(
    () => service ?? CaseAnalysisApiService(),
    [service],
  );

  final entries = useState<List<HistoryEntry>>([]);
  final isLoading = useState(false);
  final errorMessage = useState<String?>(null);

  Future<void> fetchHistory() async {
    if (token == null || token.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final rawList = await caseAnalysisService.fetchCaseAnalysisHistory(token: token);

      entries.value = rawList.map((raw) {
        DateTime timestamp;
        try {
          timestamp = DateTime.parse(raw['timestamp'] ?? '');
        } catch (_) {
          timestamp = DateTime.now();
        }

        return HistoryEntry(
          id: (raw['id'] ?? '').toString(),
          filename: (raw['filename'] ?? 'Processo sem nome').toString(),
          timestamp: timestamp,
          summary: raw['case_summary'] is String ? raw['case_summary'] : null,
          precedents: const [],
        );
      }).toList();
    } on CaseAnalysisApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Não foi possível carregar o histórico de processos.';
    } finally {
      isLoading.value = false;
    }
  }

  useEffect(() {
    fetchHistory();
    return null;
  }, [token]);

  return JudgeCaseHistoryController(
    entries: entries.value,
    isLoading: isLoading.value,
    errorMessage: errorMessage.value,
    refresh: fetchHistory,
  );
}
