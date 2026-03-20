import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? method;
  final String? path;
  final String? responseBody;
  final Object? cause;

  const AuthApiException(
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
      if (method != null || path != null) 'request: ${method ?? '-'} ${path ?? '-'}',
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

class AuthUser {
  final String id;
  final String email;
  final String username;
  final String role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = _pickString(json, ['id', '_id', 'userId', 'sub'], fallback: '');
    final email = _pickString(json, ['email'], fallback: '');
    final username = _pickString(json, ['username', 'name'], fallback: 'Usuario');
    final role = _pickString(json, ['role'], fallback: 'USER');

    return AuthUser(id: id, email: email, username: username, role: role);
  }

  static String _pickString(
    Map<String, dynamic> json,
    List<String> keys, {
    required String fallback,
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }
}

class AuthSession {
  final AuthUser user;
  final String? token;

  const AuthSession({required this.user, required this.token});
}

class AuthApiService {
  final http.Client _httpClient;
  final String _baseUrl;

  AuthApiService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = (baseUrl ?? dotenv.env['AUTH_API_BASE_URL'] ?? '').trim();

  Future<void> registerUser({
    required String username,
    required String email,
    required String password,
  }) async {
    _assertConfigured();

    const path = '/users';

    final response = await _httpClient
        .post(
          _uri(path),
          headers: _headers(),
          body: jsonEncode({
            'email': email,
            'username': username,
            'password': password,
            'role': 'USER',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(
        response: response,
        method: 'POST',
        path: path,
      );
    }
  }

  Future<AuthSession> login({required String email, required String password}) async {
    _assertConfigured();

    const path = '/auth/login';

    final response = await _httpClient
        .post(
          _uri(path),
          headers: _headers(),
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(
        response: response,
        method: 'POST',
        path: path,
      );
    }

    final parsed = _decodeBody(response.body);
    final token = _extractToken(parsed);

    final userFromLogin = _extractUser(parsed);
    if (userFromLogin != null) {
      return AuthSession(user: userFromLogin, token: token);
    }

    if (token != null && token.isNotEmpty) {
      final profile = await getProfile(token: token);
      return AuthSession(user: profile, token: token);
    }

    throw const AuthApiException('Login realizado, mas a API nao retornou dados do usuario.');
  }

  Future<AuthUser> getProfile({required String token}) async {
    _assertConfigured();

    const path = '/auth/profile';

    final response = await _httpClient
        .get(_uri(path), headers: _headers(token: token))
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(
        response: response,
        method: 'GET',
        path: path,
      );
    }

    final parsed = _decodeBody(response.body);
    final user = _extractUser(parsed);
    if (user == null) {
      throw const AuthApiException('Perfil retornado em formato inesperado.');
    }

    return user;
  }

  Future<void> logout({String? token}) async {
    if (token == null || token.isEmpty) {
      return;
    }

    _assertConfigured();

    const path = '/auth/logout';

    final response = await _httpClient
        .post(_uri(path), headers: _headers(token: token))
        .timeout(const Duration(seconds: 15));

    if (!_isSuccess(response.statusCode)) {
      throw _buildApiException(
        response: response,
        method: 'POST',
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
      throw const AuthApiException('AUTH_API_BASE_URL nao configurada no arquivo .env.');
    }
  }

  bool _isSuccess(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  Map<String, dynamic>? _decodeBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  String _errorMessage(http.Response response) {
    final parsed = _decodeBody(response.body);
    if (parsed != null) {
      final message = _pickText(parsed, ['message', 'detail', 'error', 'title']);
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    if (response.statusCode == 401) {
      return 'Credenciais invalidas.';
    }

    if (response.statusCode == 403) {
      return 'Sem permissao para executar esta operacao.';
    }

    return 'Falha na requisicao (${response.statusCode}).';
  }

  AuthApiException _buildApiException({
    required http.Response response,
    required String method,
    required String path,
  }) {
    return AuthApiException(
      _errorMessage(response),
      statusCode: response.statusCode,
      method: method,
      path: path,
      responseBody: response.body,
    );
  }

  String? _extractToken(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final token = _pickText(json, ['token', 'accessToken', 'access_token', 'jwt']);
    if (token != null && token.isNotEmpty) {
      return token;
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return _pickText(data, ['token', 'accessToken', 'access_token', 'jwt']);
    }

    return null;
  }

  AuthUser? _extractUser(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    if (_looksLikeUser(json)) {
      return AuthUser.fromJson(json);
    }

    final user = json['user'];
    if (user is Map<String, dynamic>) {
      return AuthUser.fromJson(user);
    }

    final profile = json['profile'];
    if (profile is Map<String, dynamic>) {
      return AuthUser.fromJson(profile);
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      if (_looksLikeUser(data)) {
        return AuthUser.fromJson(data);
      }

      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) {
        return AuthUser.fromJson(nestedUser);
      }
    }

    return null;
  }

  bool _looksLikeUser(Map<String, dynamic> json) {
    final hasEmail = json['email'] is String;
    final hasUsername = json['username'] is String || json['name'] is String;
    return hasEmail || hasUsername;
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