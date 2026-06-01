import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CaseAnalysisApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const CaseAnalysisApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() => message;
}

/// API Service para análise de PROCESSOS (Frente 2 - Juiz)
/// Utiliza rota: POST /petition/analyze-case
class CaseAnalysisApiService {
  final http.Client _httpClient;
  final String _baseUrl;

  CaseAnalysisApiService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl =
          (baseUrl ??
                  dotenv.env['THEMIS_API_BASE_URL'] ??
                  dotenv.env['AUTH_API_BASE_URL'] ??
                  '')
              .trim();

  /// Análise de PROCESSO para o Juiz.
  /// 1. POST /petition/analyze-case → retorna job_id
  /// 2. Polls /petition/case-status/{job_id} até status == "done"
  /// 3. Formata e retorna o resultado com minuta
  Future<Map<String, dynamic>> analyzeCaseWithPolling({
    required String token,
    required String fileName,
    required Uint8List pdfBytes,
    required int candidates,
    Function(String)? onStatusUpdate,
  }) async {
    _assertConfigured();

    if (candidates <= 0) {
      throw const CaseAnalysisApiException('Quantidade de precedentes inválida.');
    }

    // Step 1: Envia o PDF para /petition/analyze-case e recebe job_id
    onStatusUpdate?.call('Enviando processo para análise...');
    final jobId = await _analyzeCase(token, fileName, pdfBytes);

    // Step 2: Poll até concluir
    onStatusUpdate?.call('Analisando processo... (etapa 1/3)');
    final result = await _pollCaseStatus(token, jobId, onStatusUpdate);

    // Step 3: Formata
    return _formatAnalysisResult(result, candidates);
  }

  /// Calls the analyze-case endpoint and returns the job_id
  Future<String> _analyzeCase(
    String token,
    String fileName,
    Uint8List pdfBytes,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/petition/analyze-case'),
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
      debugPrint('[CaseAnalysisAPI] Enviando PDF para analyze-case');
      debugPrint('[CaseAnalysisAPI] URL: ${request.url}');
    }

    final streamedResponse = await _httpClient
        .send(request)
        .timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);

    if (kDebugMode) {
      debugPrint(
        '[CaseAnalysisAPI] Resposta analyze-case - Status: ${response.statusCode}',
      );
      debugPrint('[CaseAnalysisAPI] Body: ${response.body}');
    }

    if (!_isSuccess(response.statusCode)) {
      throw CaseAnalysisApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    if (parsed == null) {
      throw const CaseAnalysisApiException('Resposta inesperada do servidor.');
    }

    final jobId = parsed['job_id'] as String?;
    if (jobId == null || jobId.isEmpty) {
      throw const CaseAnalysisApiException('Job ID não retornado pelo servidor.');
    }

    if (kDebugMode) {
      debugPrint('[CaseAnalysisAPI] Job ID recebido: $jobId');
    }

    return jobId;
  }

  /// Polls /petition/case-status/{job_id} until status is "done"
  Future<Map<String, dynamic>> _pollCaseStatus(
    String token,
    String jobId,
    Function(String)? onStatusUpdate,
  ) async {
    const maxAttempts = 300; // 5 minutes max (1 second interval)
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
          throw CaseAnalysisApiException(
            _errorMessage(response),
            statusCode: response.statusCode,
            responseBody: response.body,
          );
        }

        final parsed = _decodeBody(response.body);
        if (parsed == null) {
          throw const CaseAnalysisApiException('Resposta inesperada do servidor.');
        }

        final status = parsed['status'] as String?;
        if (status == 'done') {
          if (kDebugMode) {
            debugPrint('[CaseAnalysisAPI] Análise concluída após $attempts tentativas');
          }
          return parsed;
        }

        if (status == 'processing') {
          onStatusUpdate?.call(
            'Analisando processo... (etapa ${(attempts % 3) + 1}/3)',
          );
        }

        if (kDebugMode) {
          debugPrint('[CaseAnalysisAPI] Polling tentativa $attempts: status=$status');
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CaseAnalysisAPI] Erro durante polling: $e');
        }
        rethrow;
      }
    }

    throw const CaseAnalysisApiException(
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
      throw const CaseAnalysisApiException('Estrutura de resposta inesperada.');
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

  /// Fetches the case analysis history for the Judge front.
  /// Calls GET /petition/case-analysis-history.
  Future<List<Map<String, dynamic>>> fetchCaseAnalysisHistory({
    required String token,
  }) async {
    _assertConfigured();

    final response = await _httpClient
        .get(
          _uri('/petition/case-analysis-history'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));

    if (!_isSuccess(response.statusCode)) {
      throw CaseAnalysisApiException(
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

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  void _assertConfigured() {
    if (_baseUrl.isEmpty) {
      throw const CaseAnalysisApiException(
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
          'Falha interna ao analisar processo. Tente novamente em instantes.';
    }

    return fromBody ?? 'Falha ao analisar processo (${response.statusCode}).';
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
