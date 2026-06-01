import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class PetitionApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const PetitionApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() => message;
}

class PetitionApiService {
  final http.Client _httpClient;
  final String _baseUrl;

  PetitionApiService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl =
          (baseUrl ??
                  dotenv.env['THEMIS_API_BASE_URL'] ??
                  dotenv.env['AUTH_API_BASE_URL'] ??
                  '')
              .trim();

  /// Analyzes a petition with polling.
  /// 1. Calls analyze-case-test to get job_id
  /// 2. Polls /petition/case-status/{job_id} until done
  /// 3. Returns full result including minuta
  Future<Map<String, dynamic>> analyzeWithPolling({
    required String token,
    required String fileName,
    required Uint8List pdfBytes,
    required int candidates,
    Function(String)? onStatusUpdate,
  }) async {
    _assertConfigured();

    if (candidates <= 0) {
      throw const PetitionApiException('Quantidade de precedentes invalida.');
    }

    // Step 0: Dispara a rota antiga em background para forçar a atualização do histórico
    try {
      final historyRequest = http.MultipartRequest(
        'POST',
        _uri('/petition/analyze'),
      );
      historyRequest.headers['Authorization'] = 'Bearer $token';
      historyRequest.files.add(
        http.MultipartFile.fromBytes(
          'file',
          pdfBytes,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ),
      );

      // Fire and forget: enviamos a requisição sem esperar o processamento finalizar
      _httpClient
          .send(historyRequest)
          .catchError((_) => http.StreamedResponse(const Stream.empty(), 500));
      if (kDebugMode) {
        debugPrint(
          '[API] Disparado envio em background para /petition/analyze (para histórico)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[API] Erro ao disparar background para histórico: $e');
      }
    }

    // Step 1: Call analyze-case-test to get job_id
    onStatusUpdate?.call('Enviando arquivo para análise...');
    final jobId = await _analyzeCase(token, fileName, pdfBytes);

    // Step 2: Poll for results
    onStatusUpdate?.call('Analisando caso... (etapa 1/3)');
    final result = await _pollCaseStatus(token, jobId, onStatusUpdate);

    // Step 3: Extract and format results
    return _formatAnalysisResult(result, candidates);
  }

  /// 1. POST /petition/analyze-case  → retorna job_id
  /// 2. Polls /petition/case-status/{job_id} até status == "done"
  /// 3. Formata e retorna o resultado
  Future<Map<String, dynamic>> analyzeCaseWithPolling({
    required String token,
    required String fileName,
    required Uint8List pdfBytes,
    required int candidates,
    Function(String)? onStatusUpdate,
  }) async {
    _assertConfigured();

    if (candidates <= 0) {
      throw const PetitionApiException('Quantidade de precedentes inválida.');
    }

    // Step 1: Envia o PDF para /petition/analyze-case e recebe job_id
    onStatusUpdate?.call('Enviando processo para análise...');

    final request = http.MultipartRequest(
      'POST',
      _uri('/petition/analyze-case-test'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        pdfBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    if (kDebugMode) {
      debugPrint('[API] Enviando PDF para /petition/analyze-case-test');
    }

    final streamedResponse =
        await _httpClient.send(request).timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    if (parsed == null) {
      throw const PetitionApiException('Resposta inesperada do servidor.');
    }

    final jobId = parsed['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const PetitionApiException('Job ID não retornado pelo servidor.');
    }

    if (kDebugMode) debugPrint('[API] Job ID (case): $jobId');

    // Step 2: Poll até concluir
    onStatusUpdate?.call('Analisando processo... (etapa 1/3)');
    final result = await _pollCaseStatus(token, jobId, onStatusUpdate);

    // Step 3: Formata
    return _formatAnalysisResult(result, candidates);
  }

  /// Calls the analyze-case-test endpoint and returns the job_id
  Future<String> _analyzeCase(
    String token,
    String fileName,
    Uint8List pdfBytes,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/petition/analyze-case-test'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        pdfBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    if (kDebugMode) {
      debugPrint('[API] Enviando PDF para analyze-case-test');
      debugPrint('[API] URL: ${request.url}');
    }

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (kDebugMode) {
      debugPrint(
        '[API] Resposta analyze-case-test - Status: ${response.statusCode}',
      );
      debugPrint('[API] Body: ${response.body}');
    }

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    if (parsed == null) {
      throw const PetitionApiException('Resposta inesperada do servidor.');
    }

    final jobId = parsed['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const PetitionApiException('Job ID não retornado pelo servidor.');
    }

    if (kDebugMode) {
      debugPrint('[API] Job ID recebido: $jobId');
    }

    return jobId;
  }

  /// Polls /petition/case-status/{job_id} until status is "done"
  Future<Map<String, dynamic>> _pollCaseStatus(
    String token,
    String jobId,
    Function(String)? onStatusUpdate,
  ) async {
    const maxAttempts = 120; // 2 minutes max (1 second interval)
    const pollInterval = Duration(seconds: 5);
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;

      try {
        final response = await _httpClient
            .get(
              _uri('/petition/case-status/$jobId'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 30));

        if (!_isSuccess(response.statusCode)) {
          throw PetitionApiException(
            _errorMessage(response),
            statusCode: response.statusCode,
            responseBody: response.body,
          );
        }

        final parsed = _decodeBody(response.body);
        if (parsed == null) {
          throw const PetitionApiException('Resposta inesperada do servidor.');
        }

        final status = parsed['status'] as String?;
        if (status == 'done') {
          if (kDebugMode) {
            debugPrint('[API] Análise concluída após $attempts tentativas');
          }
          return parsed;
        }

        if (status == 'processing') {
          onStatusUpdate?.call(
            'Analisando caso... (etapa ${(attempts % 3) + 1}/3)',
          );
        }

        if (kDebugMode) {
          debugPrint('[API] Polling tentativa $attempts: status=$status');
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[API] Erro durante polling: $e');
        }
        rethrow;
      }
    }

    throw const PetitionApiException(
      'Análise demorou muito. Tente novamente em instantes.',
    );
  }

  /// Formats the case status result into the expected analysis format
  Map<String, dynamic> _formatAnalysisResult(
    Map<String, dynamic> caseStatus,
    int candidates,
  ) {
    final result = caseStatus['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw const PetitionApiException('Estrutura de resposta inesperada.');
    }

    // Extract precedent results
    final precedentResults =
        result['precedent_results'] as List<dynamic>? ?? [];
    final resultsList = precedentResults
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(candidates)
        .toList();

    // Build analysis data with minuta
    final analysisData = <String, dynamic>{
      'minuta': result['minuta'] as String? ?? '',
      'case_summary': result['case_summary'] as String? ?? '',
      'petition_summary': result['petition_summary'] as String? ?? '',
      'documents': result['documents'] as List<dynamic>? ?? [],
      'filename': result['filename'] as String? ?? '',
    };

    return {
      'results': resultsList,
      'summary': result['case_summary'] as String?,
      'analysis_data': analysisData,
    };
  }

  /// Returns a map with keys `results` (List<Map<String, dynamic>>) and
  /// `summary` (String?).
  Future<Map<String, dynamic>> analyzePetition({
    required String token,
    required String fileName,
    required Uint8List pdfBytes,
    required int candidates,
  }) async {
    _assertConfigured();

    if (candidates <= 0) {
      throw const PetitionApiException('Quantidade de precedentes invalida.');
    }

    final request = http.MultipartRequest('POST', _uri('/petition/analyze'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        pdfBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    );

    if (kDebugMode) {
      debugPrint('[API] Enviando PDF para análise');
      debugPrint('[API] URL: ${request.url}');
      debugPrint('[API] Arquivo: $fileName (${pdfBytes.length} bytes)');
    }

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (kDebugMode) {
      debugPrint('[API] Resposta - Status: ${response.statusCode}');
      debugPrint('[API] Body: ${response.body}');
    }

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    if (parsed == null) {
      throw const PetitionApiException(
        'Resposta da análise em formato inesperado.',
      );
    }

    final results = parsed['results'];
    if (results is! List || results.isEmpty) {
      throw const PetitionApiException(
        'Nenhum precedente encontrado na base Pangea para este caso.',
      );
    }

    final resultsList = results
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (kDebugMode) {
      debugPrint('[API] Análise completa. Resultados: ${resultsList.length}');
    }

    return {
      'results': resultsList,
      'summary': parsed['summary'] is String ? parsed['summary'] : null,
    };
  }

  /// Fetches the petition analysis history for the authenticated user.
  /// Returns a list of raw history entry maps.
  Future<List<Map<String, dynamic>>> fetchHistory({
    required String token,
  }) async {
    _assertConfigured();

    final response = await _httpClient
        .get(
          _uri('/petition/history'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    final history = parsed?['history'];
    if (history is! List) {
      return [];
    }

    return history
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Fetches the generated petitions history for the Lawyer front (Frente 1).
  /// Calls GET /petition/generated-history.
  Future<List<Map<String, dynamic>>> fetchGeneratedHistory({
    required String token,
  }) async {
    _assertConfigured();

    final response = await _httpClient
        .get(
          _uri('/petition/generated-history'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    final history = parsed?['history'];
    if (history is! List) {
      return [];
    }

    return history
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Generates a petition from a case description.
  /// 1. POST /petition/generate → job_id
  /// 2. Polls /petition/case-status/{job_id} until done
  /// 3. Returns petition text
  Future<Map<String, dynamic>> generatePetitionWithPolling({
    required String token,
    required String caseDescription,
    String? orgaoFilter,
    Uint8List? pdfBytes,
    String? pdfFileName,
    Function(String)? onStatusUpdate,
  }) async {
    _assertConfigured();

    onStatusUpdate?.call('Iniciando geração da petição...');

    final request = http.MultipartRequest('POST', _uri('/petition/generate'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['case_description'] = caseDescription;
    if (orgaoFilter != null && orgaoFilter.isNotEmpty) {
      request.fields['orgao_filter'] = orgaoFilter;
    }
    if (pdfBytes != null && pdfFileName != null && pdfBytes.isNotEmpty) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          pdfBytes,
          filename: pdfFileName,
          contentType: MediaType('application', 'pdf'),
        ),
      );
    }

    if (kDebugMode) {
      debugPrint('[API] POST /petition/generate — orgao_filter=$orgaoFilter');
    }

    final streamedResponse =
        await _httpClient.send(request).timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (kDebugMode) {
      debugPrint('[API] generate status: ${response.statusCode}');
      debugPrint('[API] generate body: ${response.body}');
    }

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    final jobId = parsed?['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const PetitionApiException('Job ID não retornado pelo servidor.');
    }

    if (kDebugMode) debugPrint('[API] Job ID (generate): $jobId');

    onStatusUpdate?.call('Gerando petição... (etapa 1/3)');
    final result = await _pollCaseStatus(token, jobId, onStatusUpdate);

    return _formatPetitionResult(result);
  }

  /// Regenerates a petition given the current text and optional instructions.
  /// 1. POST /petition/regenerate → job_id
  /// 2. Polls /petition/case-status/{job_id} until done
  /// 3. Returns new petition text
  Future<Map<String, dynamic>> regeneratePetitionWithPolling({
    required String token,
    required String caseDescription,
    String? petitionText,
    String? instructions,
    Function(String)? onStatusUpdate,
  }) async {
    _assertConfigured();

    onStatusUpdate?.call('Regenerando petição...');

    final body = <String, dynamic>{
      'case_description': caseDescription,
      if (petitionText != null && petitionText.isNotEmpty)
        'petition_text': petitionText,
      if (instructions != null && instructions.isNotEmpty)
        'instructions': instructions,
    };

    if (kDebugMode) {
      debugPrint('[API] POST /petition/regenerate');
    }

    final response = await _httpClient
        .post(
          _uri('/petition/regenerate'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(minutes: 5));

    if (kDebugMode) {
      debugPrint('[API] regenerate status: ${response.statusCode}');
      debugPrint('[API] regenerate body: ${response.body}');
    }

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    final jobId = parsed?['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const PetitionApiException('Job ID não retornado pelo servidor.');
    }

    if (kDebugMode) debugPrint('[API] Job ID (regenerate): $jobId');

    final result = await _pollCaseStatus(token, jobId, onStatusUpdate);

    return _formatPetitionResult(result);
  }

  /// Extracts petition text, precedents and weak_precedents flag from a polling result.
  Map<String, dynamic> _formatPetitionResult(Map<String, dynamic> statusResult) {
    final result = statusResult['result'] as Map<String, dynamic>? ?? statusResult;

    final petitionText = result['petition_text'] as String?
        ?? result['petition'] as String?
        ?? result['text'] as String?
        ?? result['minuta'] as String?
        ?? '';

    final precedentResults =
        (result['precedent_results'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    final weakPrecedents = result['weak_precedents'] as bool? ?? false;

    return {
      'petition_text': petitionText,
      'precedent_results': precedentResults,
      'weak_precedents': weakPrecedents,
    };
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  void _assertConfigured() {
    if (_baseUrl.isEmpty) {
      throw const PetitionApiException(
        'THEMIS_API_BASE_URL nao configurada no arquivo .env.',
      );
    }
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  String _errorMessage(http.Response response) {
    final parsed = _decodeBody(response.body);
    final fromBody = parsed != null
        ? _pickText(parsed, ['detail', 'message', 'error'])
        : null;

    if (response.statusCode == 401) {
      return 'Sessao expirada. Faca login novamente.';
    }

    if (response.statusCode == 404) {
      return 'Nenhum precedente encontrado na base Pangea para este caso.';
    }

    if (response.statusCode == 400) {
      return fromBody ?? 'Arquivo invalido. Envie um PDF valido.';
    }

    if (response.statusCode == 500) {
      return fromBody ??
          'Falha interna ao analisar peticao. Tente novamente em instantes.';
    }

    return fromBody ?? 'Falha ao analisar peticao (${response.statusCode}).';
  }

  Map<String, dynamic>? _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? _pickText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
