import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SettingsApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? method;
  final String? path;
  final String? responseBody;
  final Object? cause;

  const SettingsApiException(
    this.message, {
    this.statusCode,
    this.method,
    this.path,
    this.responseBody,
    this.cause,
  });

  String toDebugString() {
    final parts = <String>[
      'message: $message',
      if (method != null || path != null)
        'request: ${method ?? '-'} ${path ?? '-'}',
      if (statusCode != null) 'statusCode: $statusCode',
      if (responseBody != null && responseBody!.trim().isNotEmpty)
        'responseBody: ${responseBody!.trim()}',
      if (cause != null) 'cause: $cause',
    ];
    return parts.join(' | ');
  }

  @override
  String toString() => message;
}

class SettingsApiService {
  final http.Client _httpClient;
  final String _baseUrl;

  SettingsApiService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? dotenv.env['AUTH_API_BASE_URL'] ?? '').trim();

  Future<void> updateUserProfile({
    required String token,
    required String userId,
    required String username,
    required String email,
  }) async {
    _assertConfigured();

    final path = '/users/$userId';

    developer.log('updateUserProfile: POST $path', name: 'SettingsApiService');

    final response = await _httpClient
        .put(
          _uri(path),
          headers: _headers(token: token),
          body: jsonEncode({
            'username': username,
            'email': email,
          }),
        )
        .timeout(const Duration(seconds: 15));

    developer.log(
      'updateUserProfile: statusCode=${response.statusCode}, body=${response.body}',
      name: 'SettingsApiService',
    );

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(response: response, method: 'PUT', path: path);
    }
  }

  Future<void> changePassword({
    required String token,
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    _assertConfigured();

    final path = '/users/$userId';

    developer.log('changePassword: PUT $path', name: 'SettingsApiService');

    final response = await _httpClient
        .put(
          _uri(path),
          headers: _headers(token: token),
          body: jsonEncode({
            'currentPassword': currentPassword,
            'password': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 15));

    developer.log(
      'changePassword: statusCode=${response.statusCode}, body=${response.body}',
      name: 'SettingsApiService',
    );

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(response: response, method: 'PUT', path: path);
    }
  }

  Future<void> deleteAccount({
    required String token,
    required String userId,
  }) async {
    _assertConfigured();

    final path = '/users/$userId';

    final response = await _httpClient
        .delete(
          _uri(path),
          headers: _headers(token: token),
        )
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(response: response, method: 'DELETE', path: path);
    }
  }

  Uri _uri(String path) {
    return Uri.parse('$_baseUrl$path');
  }

  Map<String, String> _headers({String? token}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void _assertConfigured() {
    if (_baseUrl.isEmpty) {
      throw const SettingsApiException(
        'API nao esta configurada. Verifique o arquivo .env',
      );
    }
  }

  bool _isSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  String _errorMessage({
    required http.Response response,
    required String path,
  }) {
    final parsed = _decodeBody(response.body);
    final parsedMessage = parsed != null
        ? _pickText(parsed, ['message', 'detail', 'error', 'title'])
        : null;

    if (parsedMessage != null && parsedMessage.isNotEmpty) {
      return parsedMessage;
    }

    if (response.statusCode == 401) {
      return 'Sessao expirada. Faca login novamente.';
    }

    if (response.statusCode == 403) {
      return 'Sem permissao para executar esta operacao.';
    }

    if (response.statusCode == 400) {
      return 'Dados invalidos. Verifique os campos e tente novamente.';
    }

    if (response.statusCode == 404) {
      return 'Usuario nao encontrado.';
    }

    return 'Falha na requisicao (${response.statusCode}).';
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

  SettingsApiException _buildApiException({
    required http.Response response,
    required String method,
    required String path,
  }) {
    return SettingsApiException(
      _errorMessage(response: response, path: path),
      statusCode: response.statusCode,
      method: method,
      path: path,
      responseBody: response.body,
    );
  }

  String? _pickText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
