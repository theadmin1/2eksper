import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final dynamic details;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Eski sunucu sürümleri bazı JSON sütunlarını çözmeden String olarak
/// döndürebilir. Bu yardımcı hem yeni nesne/dizi cevaplarını hem eski JSON
/// metinlerini tek biçime getirir.
class ApiData {
  const ApiData._();

  static dynamic decoded(dynamic value, [int depth = 0]) {
    if (depth >= 6) return value;
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry('$key', decoded(item, depth + 1)),
      );
    }
    if (value is List) {
      return value.map((item) => decoded(item, depth + 1)).toList();
    }
    if (value is! String) return value;
    var text = value.trim();
    if (text.isEmpty) return null;
    if (text.contains('&quot;') || text.contains('&#34;')) {
      text = text.replaceAll('&quot;', '"').replaceAll('&#34;', '"');
    }
    if (!(text.startsWith('{') ||
        text.startsWith('[') ||
        text.startsWith('"'))) {
      return value;
    }
    try {
      final parsed = jsonDecode(text);
      if (parsed == value) return value;
      return decoded(parsed, depth + 1);
    } on FormatException {
      return value;
    }
  }

  static Map<String, dynamic> map(dynamic value) {
    final parsed = decoded(value);
    return parsed is Map ? Map<String, dynamic>.from(parsed) : {};
  }

  static List<dynamic> list(dynamic value, {bool wrapString = false}) {
    final parsed = decoded(value);
    if (parsed is List) return List<dynamic>.from(parsed);
    if (wrapString && parsed is String && parsed.trim().isNotEmpty) {
      return [parsed.trim()];
    }
    return [];
  }
}

enum ApiHealthState { checking, online, offline, serverError, unauthorized }

class ApiService {
  static String baseUrl = 'https://app.2eksper.com/api/v1';
  static const requiredApiVersion = '1.2.0';
  static const requiredReportApiRevision = 3;
  static const _standardTimeout = Duration(seconds: 35);
  static const _uploadTimeout = Duration(seconds: 120);
  static final ValueNotifier<ApiHealthState> health =
      ValueNotifier(ApiHealthState.checking);
  static Future<void> Function()? onUnauthorized;

  static String get webRoot {
    final uri = Uri.parse(baseUrl);
    final segments = List<String>.from(uri.pathSegments);
    if (segments.length >= 2 &&
        segments[segments.length - 2] == 'api' &&
        segments.last == 'v1') {
      segments.removeRange(segments.length - 2, segments.length);
    }
    return uri
        .replace(pathSegments: segments, query: null, fragment: null)
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  static String mediaUrl(dynamic value) {
    final path = '${value ?? ''}'.trim();
    if (path.isEmpty) return '';
    final uri = Uri.tryParse(path);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return uri.toString();
    }
    return Uri.parse('$webRoot/')
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''))
        .toString();
  }

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('api_base_url');
    if (saved == null) return;
    try {
      baseUrl = normalizeBaseUrl(saved);
    } on ApiException {
      await prefs.remove('api_base_url');
    }
  }

  static Future<void> setBaseUrl(String value) async {
    baseUrl = normalizeBaseUrl(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', baseUrl);
  }

  static String normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const ApiException(
        'Sunucu adresi geçerli bir HTTPS adresi olmalıdır.',
      );
    }
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (parts.length < 2 ||
        parts[parts.length - 2] != 'api' ||
        parts.last != 'v1') {
      throw const ApiException('Sunucu adresi /api/v1 ile bitmelidir.');
    }
    return uri.replace(query: null, fragment: null).toString();
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> checkConnection() async {
    final response = await get('health.php');
    if (!isCompatible(response)) {
      throw const ApiException(
        'Sunucudaki mobil API sürümü bu uygulamayla uyumlu değil.',
      );
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String endpoint, [Map<String, String>? query]) {
    var uri = Uri.parse('$baseUrl/$endpoint');
    if (query != null) uri = uri.replace(queryParameters: query);
    return uri;
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) {
    final freshQuery = <String, String>{
      ...?queryParameters,
      '_mobile_ts': '${DateTime.now().millisecondsSinceEpoch}',
    };
    return _send(
      () async => http.get(
        _uri(endpoint, freshQuery),
        headers: await _headers(),
      ),
      retrySafe: true,
    );
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool isUpload = false,
  }) {
    return _send(
      () async => http.post(
        _uri(endpoint),
        headers: await _headers(),
        body: jsonEncode(body),
      ),
      timeout: isUpload ? _uploadTimeout : _standardTimeout,
    );
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    final tunneledBody = <String, dynamic>{...body, '_method': 'PUT'};
    return _send(
      () async => http.post(
        _uri(endpoint),
        headers: await _headers(),
        body: jsonEncode(tunneledBody),
      ),
    );
  }

  static Future<Map<String, dynamic>> delete(
    String endpoint,
    Map<String, dynamic> body,
  ) {
    final tunneledBody = <String, dynamic>{...body, '_method': 'DELETE'};
    return _send(
      () async => http.post(
        _uri(endpoint),
        headers: await _headers(),
        body: jsonEncode(tunneledBody),
      ),
    );
  }

  static Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration timeout = _standardTimeout,
    bool retrySafe = false,
  }) async {
    const retryableStatus = {502, 503, 504};
    final attempts = retrySafe ? 3 : 1;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        if (attempt == 1) health.value = ApiHealthState.checking;
        final response = await request().timeout(timeout);
        final text =
            utf8.decode(response.bodyBytes, allowMalformed: true).trim();
        Map<String, dynamic>? data;
        if (text.isNotEmpty) {
          try {
            final decoded = jsonDecode(text);
            if (decoded is Map) data = Map<String, dynamic>.from(decoded);
          } on FormatException {
            data = null;
          }
        }

        final successful =
            response.statusCode >= 200 && response.statusCode < 300;
        if (!successful || data == null || data['status'] == false) {
          final fallback = switch (response.statusCode) {
            401 => 'Oturumunuz sona ermiş. Lütfen yeniden giriş yapın.',
            409 => 'Kayıt sunucuda başka bir oturum tarafından güncellendi.',
            413 => 'Gönderilen fotoğraflar sunucu sınırını aşıyor.',
            >= 500 =>
              'Sunucu işlemi tamamlayamadı. Lütfen tekrar deneyin.',
            _ => 'İşlem tamamlanamadı.',
          };
          final message = '${data?['message'] ?? fallback}'.trim();
          throw ApiException(
            message.isEmpty ? fallback : message,
            statusCode: response.statusCode,
            details: data?['errors'],
          );
        }
        health.value = ApiHealthState.online;
        return data;
      } on ApiException catch (error) {
        if (error.statusCode == 401) {
          health.value = ApiHealthState.unauthorized;
          if (await getToken() case final token? when token.isNotEmpty) {
            await onUnauthorized?.call();
          }
          rethrow;
        }
        final canRetry = retrySafe &&
            attempt < attempts &&
            retryableStatus.contains(error.statusCode);
        if (!canRetry) {
          health.value = error.statusCode != null && error.statusCode! >= 500
              ? ApiHealthState.serverError
              : ApiHealthState.online;
          rethrow;
        }
      } on TimeoutException {
        if (!retrySafe || attempt == attempts) {
          health.value = ApiHealthState.offline;
          throw const ApiException(
            'Sunucu zamanında yanıt vermedi. Bağlantınızı kontrol edip tekrar deneyin.',
          );
        }
      } on SocketException {
        if (!retrySafe || attempt == attempts) {
          health.value = ApiHealthState.offline;
          throw const ApiException(
            'İnternet bağlantısı kurulamadı. Ağ bağlantınızı kontrol edin.',
          );
        }
      } on http.ClientException {
        if (!retrySafe || attempt == attempts) {
          health.value = ApiHealthState.offline;
          throw const ApiException('Sunucuyla güvenli bağlantı kurulamadı.');
        }
      } on FormatException {
        health.value = ApiHealthState.serverError;
        throw const ApiException('Sunucu geçersiz bir yanıt gönderdi.');
      } catch (_) {
        health.value = ApiHealthState.serverError;
        throw const ApiException(
          'İşlem tamamlanamadı. Lütfen bağlantıyı kontrol edip tekrar deneyin.',
        );
      }
      await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
    }
    throw const ApiException('Sunucuya bağlanılamadı.');
  }

  static bool isCompatible(Map<String, dynamic> response) {
    final actual = '${response['api_version'] ?? ''}'.split('.');
    final required = requiredApiVersion.split('.');
    if (actual.length < 3 || required.length < 3) return false;
    for (var i = 0; i < 3; i++) {
      final current = int.tryParse(actual[i]);
      final minimum = int.tryParse(required[i]);
      if (current == null || minimum == null) return false;
      if (current > minimum) return true;
      if (current < minimum) return false;
    }
    return true;
  }
}
