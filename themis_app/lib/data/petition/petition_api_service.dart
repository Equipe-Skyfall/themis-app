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

  Future<String> _submitCaseAnalysis({
    required String token,
    required String fileName,
    required Uint8List pdfBytes,
    required int candidates,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/petition/analyze-case-test'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['candidates'] = candidates.toString();
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

    final streamedResponse = await _httpClient.send(request).timeout(
      const Duration(seconds: 90),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (kDebugMode) {
      debugPrint('[API] Resposta submissão - Status: ${response.statusCode}');
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
    final jobId = parsed?['job_id'];
    
    if (kDebugMode) {
      debugPrint('[API] Job ID recebido: $jobId');
    }
    
    if (jobId is! String || jobId.isEmpty) {
      throw const PetitionApiException(
        'Resposta da submissão em formato inesperado. Job ID não recebido.',
      );
    }

    return jobId;
  }

  /// Polls the status of a case analysis.
  /// Returns the full analysis result when complete.
  Future<Map<String, dynamic>> _pollCaseStatus({
    required String token,
    required String jobId,
    Duration timeout = const Duration(minutes: 5),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    final startTime = DateTime.now();

    while (true) {
      if (DateTime.now().difference(startTime) > timeout) {
        throw const PetitionApiException(
          'Análise expirou. Tempo limite excedido.',
        );
      }

      try {
        final response = await _httpClient.get(
          _uri('/petition/case-status/$jobId'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 30));

        if (kDebugMode) {
          debugPrint('[API] Polling status - Job: $jobId');
          debugPrint('[API] Status code: ${response.statusCode}');
        }

        if (!_isSuccess(response.statusCode)) {
          throw PetitionApiException(
            _errorMessage(response),
            statusCode: response.statusCode,
            responseBody: response.body,
          );
        }

        final parsed = _decodeBody(response.body);
        final status = parsed?['status'];

        if (kDebugMode) {
          debugPrint('[API] Status da análise: $status');
        }

        // Check if analysis is complete
        if (status == 'completed' || status == 'done') {
          final result = parsed?['result'];
          final precedentResults = result?['precedent_results'];
          final caseSummary = result?['case_summary'];
          
          if (kDebugMode) {
            debugPrint('[API] Análise completa. Resultados: ${precedentResults?.length ?? 0}');
          }
          
          if (precedentResults is! List) {
            throw const PetitionApiException(
              'Nenhum precedente encontrado na base Pangea para este caso.',
            );
          }

          if (precedentResults.isEmpty) {
            throw const PetitionApiException(
              'Nenhum precedente encontrado na base Pangea para este caso.',
            );
          }

          final resultsList = precedentResults
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();

          return {
            'results': resultsList,
            'summary': caseSummary is String ? caseSummary : null,
          };
        }

        // Still processing, wait before next poll
        if (kDebugMode) {
          debugPrint('[API] Aguardando análise... (status: $status)');
          debugPrint('[API] Próximo poll em ${pollInterval.inSeconds}s...');
        }
        await Future.delayed(pollInterval);
      } catch (e) {
        // If it's already our exception, rethrow
        if (e is PetitionApiException) rethrow;
        // Otherwise wrap it
        if (kDebugMode) {
          debugPrint('[API] Erro no polling: $e');
        }
        throw PetitionApiException(
          'Erro ao verificar status da análise: $e',
        );
      }
    }
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

    // Submit case for analysis and get job ID
    final jobId = await _submitCaseAnalysis(
      token: token,
      fileName: fileName,
      pdfBytes: pdfBytes,
      candidates: candidates,
    );

    // Poll for results
    return await _pollCaseStatus(
      token: token,
      jobId: jobId,
    );
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
