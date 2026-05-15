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

    final streamedResponse = await _httpClient.send(request).timeout(
      const Duration(minutes: 5),
    );
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

    final response = await _httpClient.get(
      _uri('/petition/history'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));

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
