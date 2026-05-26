// themis_app/lib/hooks/use_case_history_controller.dart
import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/petition/petition_api_service.dart';
import '../lib/models.dart';

/// Entry retornada por /petition/case-analysis-history
class CaseAnalysisEntry {
  final String id;
  final String filename;
  final DateTime timestamp;
  final String caseSummary;
  final String? minuta;

  const CaseAnalysisEntry({
    required this.id,
    required this.filename,
    required this.timestamp,
    required this.caseSummary,
    this.minuta,
  });

  /// Converte para HistoryEntry para reutilizar os cards existentes.
  HistoryEntry toHistoryEntry() => HistoryEntry(
        id: id,
        filename: filename,
        timestamp: timestamp,
        summary: caseSummary,
        precedents: const [],
      );
}

class CaseHistoryController {
  final List<HistoryEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() refresh;

  const CaseHistoryController({
    required this.entries,
    required this.isLoading,
    required this.errorMessage,
    required this.refresh,
  });
}

CaseHistoryController useCaseHistoryController({
  required String? token,
  PetitionApiService? service,
}) {
  final petitionService = useMemoized(
    () => service ?? PetitionApiService(),
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
      final rawList = await petitionService.fetchCaseAnalysisHistory(token: token);

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
    } on PetitionApiException catch (e) {
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

  return CaseHistoryController(
    entries: entries.value,
    isLoading: isLoading.value,
    errorMessage: errorMessage.value,
    refresh: fetchHistory,
  );
}
