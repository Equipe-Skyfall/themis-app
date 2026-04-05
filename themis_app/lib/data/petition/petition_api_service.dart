import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

  Future<List<Map<String, dynamic>>> analyzePetition({
    required String token,
    required String fileName,
    required Uint8List pdfBytes,
  }) async {
    _assertConfigured();

    final request = http.MultipartRequest('POST', _uri('/petition/analyze'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', pdfBytes, filename: fileName),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 90),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (!_isSuccess(response.statusCode)) {
      throw PetitionApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final parsed = _decodeBody(response.body);
    final results = parsed?['results'];
    if (results is! List) {
      throw const PetitionApiException(
        'Resposta da análise em formato inesperado.',
      );
    }

    return results
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

    if (response.statusCode == 400) {
      return fromBody ?? 'Arquivo invalido. Envie um PDF valido.';
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
