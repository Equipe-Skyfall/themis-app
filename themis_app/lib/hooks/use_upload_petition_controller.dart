import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:themis_app/data/petition/petition_api_service.dart';
import 'package:themis_app/data/petition/case_analysis_api_service.dart';
import 'package:themis_app/lib/models.dart';

class AnalysisResult {
  final List<Precedent> precedents;
  final String? summary;
  final Map<String, dynamic>? analysisData;

  const AnalysisResult({
    required this.precedents,
    this.summary,
    this.analysisData,
  });
}

class UploadPetitionController {
  final PlatformFile? selectedFile;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function() pickPDF;

  /// Análise de petição — Advogado
  final Future<AnalysisResult?> Function({required int limit}) generateAnalysis;

  /// Análise de processo — Juiz
  final Future<AnalysisResult?> Function({required int limit}) generateCaseAnalysis;

  const UploadPetitionController({
    required this.selectedFile,
    required this.isSubmitting,
    required this.errorMessage,
    required this.pickPDF,
    required this.generateAnalysis,
    required this.generateCaseAnalysis,
  });
}

UploadPetitionController useUploadPetitionController({
  required String? token,
  PetitionApiService? service,
  CaseAnalysisApiService? caseAnalysisService,
}) {
  final petitionService = useMemoized(
    () => service ?? PetitionApiService(),
    [service],
  );

  final caseService = useMemoized(
    () => caseAnalysisService ?? CaseAnalysisApiService(),
    [caseAnalysisService],
  );

  final selectedFile = useState<PlatformFile?>(null);
  final isSubmitting = useState(false);
  final errorMessage = useState<String?>(null);

  Future<void> pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    selectedFile.value = result.files.first;
    errorMessage.value = null;
  }

  (String, Uint8List)? validateInput() {
    final tok = token;
    if (tok == null || tok.isEmpty) {
      errorMessage.value = 'Sessão expirada. Faça login novamente.';
      return null;
    }
    final file = selectedFile.value;
    if (file == null) {
      errorMessage.value = 'Selecione um PDF primeiro.';
      return null;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      errorMessage.value = 'Não foi possível ler o PDF. Tente selecionar novamente.';
      return null;
    }
    return (file.name, bytes);
  }

  // ── Análise de PETIÇÃO (Advogado) → petitionService → /analyze-case-test ──
  Future<AnalysisResult?> generateAnalysis({required int limit}) async {
    if (limit <= 0) {
      errorMessage.value = 'Quantidade de precedentes inválida.';
      return null;
    }
    final validated = validateInput();
    if (validated == null) return null;
    final (fileName, bytes) = validated;

    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final response = await petitionService.analyzeWithPolling(
        token: token ?? '',
        fileName: fileName,
        pdfBytes: bytes,
        candidates: limit,
        onStatusUpdate: null,
      );

      final rawResults = response['results'] as List<Map<String, dynamic>>;
      final summary = response['summary'] as String?;
      final analysisData = response['analysis_data'] as Map<String, dynamic>?;

      return AnalysisResult(
        precedents: rawResults.map(toPrecedent).toList(),
        summary: summary,
        analysisData: analysisData,
      );
    } on PetitionApiException catch (e) {
      errorMessage.value = e.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Não foi possível concluir a análise agora.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  // ── Análise de PROCESSO (Juiz) → caseService → /analyze-case ──────────────
  Future<AnalysisResult?> generateCaseAnalysis({required int limit}) async {
    if (limit <= 0) {
      errorMessage.value = 'Quantidade de precedentes inválida.';
      return null;
    }
    final validated = validateInput();
    if (validated == null) return null;
    final (fileName, bytes) = validated;

    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final response = await caseService.analyzeCaseWithPolling(
        token: token ?? '',
        fileName: fileName,
        pdfBytes: bytes,
        candidates: limit,
      );

      final rawList = response['results'];
      final rawResults = (rawList is List)
          ? rawList
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final summary = response['summary'] as String?;
      final analysisData = response['analysis_data'] as Map<String, dynamic>?;

      return AnalysisResult(
        precedents: rawResults.map(toPrecedent).toList(),
        summary: summary,
        analysisData: analysisData,
      );
    } on CaseAnalysisApiException catch (e) {
      errorMessage.value = e.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Não foi possível analisar o processo agora.';
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  return UploadPetitionController(
    selectedFile: selectedFile.value,
    isSubmitting: isSubmitting.value,
    errorMessage: errorMessage.value,
    pickPDF: pickPDF,
    generateAnalysis: generateAnalysis,
    generateCaseAnalysis: generateCaseAnalysis,
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

Precedent toPrecedent(Map<String, dynamic> item) {
  final relevance = _normalizeLabel((item['relevance_label'] ?? '').toString());
  final status = switch (relevance) {
    'aplicavel' => 'applicable',
    'possivelmente aplicavel' => 'possibly_applicable',
    'nao aplicavel' => 'not_applicable',
    _ => 'possibly_applicable',
  };

  final rawId = (item['id'] ?? '').toString().trim();
  final explanation = (item['explanation'] ?? '').toString().trim();
  final enunciado =
      _pickFirstText(item, ['textoEmenta', 'textoDecisao']) ?? explanation;
  final tese = (item['tese'] ?? '').toString().trim();
  final situacao = _mapSituacao((item['situacao'] ?? '').toString());

  return Precedent(
    id: rawId,
    title: rawId.isNotEmpty ? rawId : 'ID não informado',
    tribunal: (item['orgao'] ?? 'Tribunal não informado').toString(),
    similarity: _toDouble(item['similarity_score']),
    status: status,
    legalStatus: (item['relevance_label'] ?? '').toString(),
    situacao: situacao,
    theme: (item['questao'] ?? 'Tema não informado').toString(),
    thesis: tese.isNotEmpty ? tese : explanation,
    summary: enunciado.isNotEmpty ? enunciado : 'Não informado',
    whyApplies: explanation.isNotEmpty ? explanation : 'Não informado',
  );
}

String _mapSituacao(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return value;
  final normalized = _normalizeLabel(value);
  if (normalized == 'admitido_possivel_revisao_tese') {
    return 'Admitido (possível revisão de tese)';
  }
  return value;
}

String _normalizeLabel(String raw) {
  var value = raw.toLowerCase().trim();
  value = value
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
  return value;
}

double _toDouble(Object? value) {
  if (value is num) {
    var asDouble = value.toDouble();
    if (asDouble >= 0 && asDouble <= 1) asDouble = asDouble * 100;
    return asDouble.clamp(0, 100);
  }
  if (value is String) {
    var parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed != null) {
      if (parsed >= 0 && parsed <= 1) parsed = parsed * 100;
      return parsed.clamp(0, 100);
    }
  }
  return 0;
}

String? _pickFirstText(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}