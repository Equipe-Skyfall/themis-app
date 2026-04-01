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

    final payload = {
      'username': username,
      'email': email,
    };

    final candidates = <({String method, String path})>[
      (method: 'PUT', path: '/users/$userId'),
      (method: 'PATCH', path: '/users/$userId'),
    ];

    SettingsApiException? lastError;

<<<<<<< settingsPage
    for (final candidate in candidates) {
      final response = await _sendJson(
        method: candidate.method,
        path: candidate.path,
        token: token,
        payload: payload,
      );
=======
    final response = await _httpClient
        .put(
          _uri(path),
          headers: _headers(token: token),
          body: jsonEncode({'username': username, 'email': email}),
        )
        .timeout(const Duration(seconds: 15));
>>>>>>> dev

      developer.log(
        'updateUserProfile: ${candidate.method} ${candidate.path} statusCode=${response.statusCode}, body=${response.body}',
        name: 'SettingsApiService',
      );

      if (_isSuccess(response.statusCode)) {
        return;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw _buildApiException(
          response: response,
          method: candidate.method,
          path: candidate.path,
        );
      }

     
      if (response.statusCode == 400 ||
          response.statusCode == 409 ||
          response.statusCode == 422) {
        throw _buildApiException(
          response: response,
          method: candidate.method,
          path: candidate.path,
        );
      }

      lastError = _buildApiException(
        response: response,
        method: candidate.method,
        path: candidate.path,
      );
    }

    throw lastError ??
        const SettingsApiException('Nao foi possivel atualizar o perfil.');
  }

  Future<void> changePassword({
    required String token,
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    _assertConfigured();

<<<<<<< settingsPage
    final variants = <Map<String, dynamic>>[
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
      {
        'currentPassword': currentPassword,
        'password': newPassword,
      },
      {
        'oldPassword': currentPassword,
        'newPassword': newPassword,
      },
      {
        'old_password': currentPassword,
        'new_password': newPassword,
      },
    ];

    final candidates = <({String method, String path})>[
      (method: 'PUT', path: '/users/$userId'),
      (method: 'PATCH', path: '/users/$userId'),
      (method: 'PUT', path: '/users/$userId/password'),
      (method: 'PATCH', path: '/users/$userId/password'),
    ];

    SettingsApiException? lastError;

    for (final candidate in candidates) {
      for (final payload in variants) {
        final response = await _sendJson(
          method: candidate.method,
          path: candidate.path,
          token: token,
          payload: payload,
        );

        developer.log(
          'changePassword: ${candidate.method} ${candidate.path} payloadKeys=${payload.keys.toList()} statusCode=${response.statusCode}, body=${response.body}',
          name: 'SettingsApiService',
        );

        if (_isSuccess(response.statusCode)) {
          return;
        }

        if (response.statusCode == 401 || response.statusCode == 403) {
          throw _buildApiException(
            response: response,
            method: candidate.method,
            path: candidate.path,
          );
        }

        if (response.statusCode == 409) {
          throw _buildApiException(
            response: response,
            method: candidate.method,
            path: candidate.path,
          );
        }

        // Senha atual incorreta deve parar e retornar para o usuario.
        if (response.statusCode == 400 || response.statusCode == 422) {
          final apiError = _buildApiException(
            response: response,
            method: candidate.method,
            path: candidate.path,
          );
          if (_looksLikeCurrentPasswordError(apiError.message, response.body)) {
            throw apiError;
          }

          throw apiError;
        }

        lastError = _buildApiException(
          response: response,
          method: candidate.method,
          path: candidate.path,
        );
      }
=======
    final payload = {
      'currentPassword': currentPassword,
      'oldPassword': currentPassword,
      'password': newPassword,
      'newPassword': newPassword,
    };

    final attempts = [
      (method: 'PUT', path: '/users/$userId', body: payload),
      (method: 'PUT', path: '/users/$userId/password', body: payload),
      (
        method: 'POST',
        path: '/auth/change-password',
        body: {...payload, 'userId': userId},
      ),
    ];

    SettingsApiException? lastError;

    for (final attempt in attempts) {
      final method = attempt.method;
      final path = attempt.path;

      developer.log(
        'changePassword: $method $path',
        name: 'SettingsApiService',
      );

      final response = await _sendJson(
        method: method,
        path: path,
        token: token,
        body: attempt.body,
      );

      developer.log(
        'changePassword: statusCode=${response.statusCode}, body=${response.body}',
        name: 'SettingsApiService',
      );

      if (_isSuccess(response.statusCode)) {
        return;
      }

      final apiError = _buildApiException(
        response: response,
        method: method,
        path: path,
      );

      // Credenciais/sessao invalidas nao devem tentar fallback.
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw apiError;
      }

      lastError = apiError;
>>>>>>> dev
    }

    throw lastError ??
        const SettingsApiException('Nao foi possivel alterar a senha.');
  }

  Future<void> deleteAccount({
    required String token,
    required String userId,
  }) async {
    _assertConfigured();

    final path = '/users/$userId';

    final response = await _httpClient
        .delete(_uri(path), headers: _headers(token: token))
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(
        response: response,
        method: 'DELETE',
        path: path,
      );
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

  Future<http.Response> _sendJson({
    required String method,
    required String path,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final uri = _uri(path);
    final headers = _headers(token: token);
    final encodedBody = jsonEncode(body);

    switch (method.toUpperCase()) {
      case 'POST':
        return _httpClient
            .post(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 15));
      case 'PUT':
      default:
        return _httpClient
            .put(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 15));
    }
  }

  String _errorMessage({
    required http.Response response,
    required String path,
  }) {
    final parsed = _decodeBody(response.body);
    final parsedMessage = parsed != null
        ? _pickText(parsed, ['message', 'detail', 'error', 'title'])
        : null;
    final errorContext = _buildErrorContext(parsed, response.body);

    if (_isValidationFailed(parsedMessage, errorContext)) {
      if (_containsAny(errorContext, ['username', 'nome'])) {
        if (_containsAny(errorContext, ['already', 'exists', 'taken', 'duplic'])) {
          return 'Nome de usuario ja utilizado.';
        }
        if (_containsAny(errorContext, ['3', 'min', 'minimum', 'at least'])) {
          return 'Nome de usuario invalido. Use ao menos 3 caracteres.';
        }
        return 'Nome de usuario invalido. Verifique e tente novamente.';
      }

      if (_containsAny(errorContext, ['email'])) {
        if (_containsAny(errorContext, ['already', 'exists', 'taken', 'duplic'])) {
          return 'Email ja utilizado.';
        }
        return 'Email invalido. Verifique e tente novamente.';
      }

      return 'Dados invalidos. Verifique os campos e tente novamente.';
    }

    if (response.statusCode == 409) {
      if (_containsAny(errorContext, ['username', 'nome'])) {
        return 'Nome de usuario ja utilizado.';
      }
      if (_containsAny(errorContext, ['email'])) {
        return 'Email ja utilizado.';
      }
      return 'Conflito de dados. Verifique os campos e tente novamente.';
    }

    if (_containsAny(errorContext, [
      'password',
      'senha',
      'current password',
      'old password',
    ])) {
      if (_containsAny(errorContext, [
        'incorrect',
        'invalid',
        'wrong',
        'mismatch',
        'nao confere',
        'incorreta',
      ])) {
        return 'Senha atual incorreta.';
      }
    }

    if (parsedMessage != null && parsedMessage.isNotEmpty) {
<<<<<<< settingsPage
      if (parsedMessage.trim().toLowerCase() == 'something went wrong') {
        if (_containsAny(errorContext, ['password', 'senha'])) {
          return 'Nao foi possivel alterar a senha. Verifique a senha atual e tente novamente.';
        }
        return 'Nao foi possivel concluir a operacao. Tente novamente.';
=======
      final lowered = parsedMessage.toLowerCase();
      if (path.contains('password') || path.contains('/users/')) {
        if (lowered.contains('something went wrong') ||
            lowered.contains('internal server error')) {
          return 'Nao foi possivel alterar a senha agora. Verifique a senha atual e tente novamente.';
        }
>>>>>>> dev
      }
      return parsedMessage;
    }

    if (response.statusCode == 401) {
      return 'Sessao expirada. Faca login novamente.';
    }

    if (response.statusCode == 403) {
      return 'Sem permissao para executar esta operacao.';
    }

    if (response.statusCode == 400) {
      if (_containsAny(errorContext, ['password', 'senha'])) {
        return 'Nao foi possivel alterar a senha. Verifique os dados informados.';
      }
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

  String _buildErrorContext(Map<String, dynamic>? json, String rawBody) {
    final parts = <String>[rawBody];

    void visit(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        parts.add(value.trim());
      } else if (value is Map) {
        for (final entry in value.entries) {
          if (entry.key is String) {
            parts.add((entry.key as String).trim());
          }
          visit(entry.value);
        }
      } else if (value is Iterable) {
        for (final item in value) {
          visit(item);
        }
      }
    }

    if (json != null) {
      visit(json);
    }

    return parts.join(' ').toLowerCase();
  }

  bool _isValidationFailed(String? parsedMessage, String errorContext) {
    if (parsedMessage != null &&
        parsedMessage.toLowerCase().contains('validation failed')) {
      return true;
    }

    return _containsAny(errorContext, [
      'validation failed',
      'validationerror',
      'bad request',
      'is invalid',
      'must be',
      'should not be empty',
      'deve',
      'invalido',
    ]);
  }

  bool _containsAny(String source, List<String> terms) {
    for (final term in terms) {
      if (source.contains(term.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  Future<http.Response> _sendJson({
    required String method,
    required String path,
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final uri = _uri(path);
    final headers = _headers(token: token);

    switch (method) {
      case 'PUT':
        return _httpClient
            .put(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 15));
      case 'PATCH':
        return _httpClient
            .patch(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 15));
      case 'POST':
        return _httpClient
            .post(uri, headers: headers, body: jsonEncode(payload))
            .timeout(const Duration(seconds: 15));
      default:
        throw SettingsApiException('Metodo HTTP nao suportado: $method');
    }
  }

  bool _looksLikeCurrentPasswordError(String message, String responseBody) {
    final source = '$message $responseBody'.toLowerCase();
    return _containsAny(source, [
      'senha atual',
      'current password',
      'old password',
      'incorrect',
      'invalid password',
      'wrong password',
    ]);
  }
}
