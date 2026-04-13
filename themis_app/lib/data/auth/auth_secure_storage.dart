import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSecureStorage {
  static const _tokenKey = 'auth_jwt_token';

  final FlutterSecureStorage _storage;

  AuthSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on MissingPluginException {
      // Plugin indisponivel nesta execucao/plataforma.
    } on PlatformException {
      // Falha de plataforma/permissionamento do storage seguro.
    }
  }

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } on MissingPluginException {
      // Plugin indisponivel nesta execucao/plataforma.
    } on PlatformException {
      // Falha de plataforma/permissionamento do storage seguro.
    }
  }
}
