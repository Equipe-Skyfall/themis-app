import 'package:file_picker/file_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../data/petition/petition_api_service.dart';
import '../lib/models.dart';

class UploadPetitionController {
  final PlatformFile? selectedFile;
  final bool isSubmitting;
  final String? errorMessage;
  final Future<void> Function() pickPDF;
  final Future<List<Precedent>?> Function() generateAnalysis;

  const UploadPetitionController({
    required this.selectedFile,
    required this.isSubmitting,
    required this.errorMessage,
    required this.pickPDF,
    required this.generateAnalysis,
  });
}

UploadPetitionController useUploadPetitionController({
  required String? token,
  PetitionApiService? service,
}) {
  final petitionService = useMemoized(() => service ?? PetitionApiService(), [
    service,
  ]);

  final selectedFile = useState<PlatformFile?>(null);
  final isSubmitting = useState(false);
  final errorMessage = useState<String?>(null);

  Future<void> pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    selectedFile.value = result.files.first;
    errorMessage.value = null;
  }

  Future<List<Precedent>?> generateAnalysis() async {
    if (token == null || token.isEmpty) {
      errorMessage.value = 'Sessao expirada. Faca login novamente.';
      return null;
    }

    final currentFile = selectedFile.value;
    if (currentFile == null) {
      errorMessage.value = 'Selecione um PDF primeiro.';
      return null;
    }

    final bytes = currentFile.bytes;
    if (bytes == null || bytes.isEmpty) {
      errorMessage.value =
          'Nao foi possivel ler o PDF selecionado. Tente selecionar novamente.';
      return null;
    }

    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      final rawResults = await petitionService.analyzePetition(
        token: token,
        fileName: currentFile.name,
        pdfBytes: bytes,
      );

      return rawResults.map(_toPrecedent).toList();
    } on PetitionApiException catch (e) {
      errorMessage.value = e.message;
      return null;
    } catch (_) {
      errorMessage.value = 'Nao foi possivel concluir a analise agora.';
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
  );
}

Precedent _toPrecedent(Map<String, dynamic> item) {
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

  return Precedent(
    id: rawId,
    title: rawId.isNotEmpty ? rawId : 'ID nao informado',
    tribunal: (item['orgao'] ?? 'Tribunal nao informado').toString(),
    similarity: _toDouble(item['similarity_score']),
    status: status,
    legalStatus: (item['relevance_label'] ?? '').toString(),
    theme: (item['questao'] ?? 'Tema nao informado').toString(),
    thesis: tese.isNotEmpty ? tese : explanation,
    summary: enunciado.isNotEmpty ? enunciado : 'Nao informado',
    whyApplies: explanation.isNotEmpty ? explanation : 'Nao informado',
  );
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
    if (asDouble >= 0 && asDouble <= 1) {
      asDouble = asDouble * 100;
    }
    return asDouble.clamp(0, 100);
  }

  if (value is String) {
    var parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed != null) {
      if (parsed >= 0 && parsed <= 1) {
        parsed = parsed * 100;
      }
      return parsed.clamp(0, 100);
    }
  }

  return 0;
}

String? _pickFirstText(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
