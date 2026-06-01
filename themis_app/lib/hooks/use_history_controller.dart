import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/petition/petition_api_service.dart';
import '../data/petition/case_analysis_api_service.dart';
import '../lib/models.dart';
import '../lib/profile_mode.dart';
import 'use_upload_petition_controller.dart' show toPrecedent;

class HistoryController {
  final List<HistoryEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() refresh;

  const HistoryController({
    required this.entries,
    required this.isLoading,
    required this.errorMessage,
    required this.refresh,
  });
}

HistoryController useHistoryController({
  required String? token,
  required ProfileMode profileMode,
  PetitionApiService? service,
}) {
  final petitionService = useMemoized(() => service ?? PetitionApiService(), [service]);
  final caseService = useMemoized(() => CaseAnalysisApiService(), []);

  final entries = useState<List<HistoryEntry>>([]);
  final isLoading = useState(false);
  final errorMessage = useState<String?>(null);

  Future<void> fetchHistory() async {
    if (token == null || token.isEmpty) {
      return;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      if (profileMode == ProfileMode.lawyer) {
        // Frente 1: GET /petition/generated-history
        final rawEntries = await petitionService.fetchGeneratedHistory(token: token);

        entries.value = rawEntries.map((raw) {
          final rawResults = raw['precedent_results'];
          final precedents = <Precedent>[];
          if (rawResults is List) {
            for (final item in rawResults) {
              if (item is Map) {
                precedents.add(toPrecedent(Map<String, dynamic>.from(item)));
              }
            }
          }

          DateTime timestamp;
          try {
            timestamp = DateTime.parse(raw['timestamp'] ?? '');
          } catch (_) {
            timestamp = DateTime.now();
          }

          final caseDescription = (raw['case_description'] ?? '').toString();
          final petitionText = raw['petition_text'] is String
              ? raw['petition_text'] as String
              : null;
          final weakPrecedents = raw['weak_precedents'] as bool? ?? false;

          return HistoryEntry(
            id: (raw['id'] ?? '').toString(),
            filename: caseDescription.isNotEmpty
                ? caseDescription
                : 'Petição sem descrição',
            timestamp: timestamp,
            summary: null,
            precedents: precedents,
            petitionText: petitionText,
            caseDescription: caseDescription,
            weakPrecedents: weakPrecedents,
          );
        }).toList();
      } else {
        // Frente 2: GET /petition/case-analysis-history
        final rawEntries = await caseService.fetchCaseAnalysisHistory(token: token);

        entries.value = rawEntries.map((raw) {
          // Campo correto é "precedent_results", não "results"
          final rawResults = raw['precedent_results'];
          final precedents = <Precedent>[];
          if (rawResults is List) {
            for (final item in rawResults) {
              if (item is Map) {
                precedents.add(toPrecedent(Map<String, dynamic>.from(item)));
              }
            }
          }

          DateTime timestamp;
          try {
            timestamp = DateTime.parse(raw['timestamp'] ?? '');
          } catch (_) {
            timestamp = DateTime.now();
          }

          // minuta vem direto no root, não em analysis_data
          final minuta = raw['minuta'] is String ? raw['minuta'] as String : null;

          // documents
          final rawDocs = raw['documents'];
          final documents = <Map<String, dynamic>>[];
          if (rawDocs is List) {
            for (final d in rawDocs) {
              if (d is Map) documents.add(Map<String, dynamic>.from(d));
            }
          }

          return HistoryEntry(
            id: (raw['id'] ?? '').toString(),
            filename: (raw['filename'] ?? 'Sem nome').toString(),
            timestamp: timestamp,
            // campo correto é "case_summary", não "summary"
            summary: raw['case_summary'] is String ? raw['case_summary'] as String : null,
            precedents: precedents,
            minuta: minuta,
            petitionSummary: raw['petition_summary'] is String ? raw['petition_summary'] as String : null,
            documents: documents,
          );
        }).toList();
      }
    } on PetitionApiException catch (e) {
      errorMessage.value = e.message;
    } on CaseAnalysisApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Nao foi possivel carregar o historico.';
    } finally {
      isLoading.value = false;
    }
  }

  // Re-fetch when token or profileMode changes
  useEffect(() {
    fetchHistory();
    return null;
  }, [token, profileMode]);

  return HistoryController(
    entries: entries.value,
    isLoading: isLoading.value,
    errorMessage: errorMessage.value,
    refresh: fetchHistory,
  );
}
