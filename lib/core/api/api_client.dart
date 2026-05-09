import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _u(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _headers({String? token}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _send(() => _client.post(
          _u(path),
          headers: _headers(token: token),
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    return _send(() => _client.get(_u(path), headers: _headers(token: token)));
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _send(() => _client.put(
          _u(path),
          headers: _headers(token: token),
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    return _send(() => _client.delete(
          _u(path),
          headers: _headers(token: token),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  /// Multipart POST. Sends [fields] alongside one file (passed as [fileBytes]
  /// + [filename]) at [fileField]. Bytes-based so the same code path works on
  /// mobile, desktop, and web — `MultipartFile.fromPath` is `dart:io`-only
  /// and throws "Unsupported operation" on Flutter web.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    String? token,
  }) async {
    return _send(() async {
      final req = http.MultipartRequest('POST', _u(path));
      req.headers['Accept'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.fields.addAll(fields);
      req.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: filename,
      ));
      final streamed = await req.send();
      return http.Response.fromStream(streamed);
    });
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() send,
  ) async {
    http.Response res;
    try {
      res = await send().timeout(ApiConfig.timeout);
    } on Exception catch (e) {
      throw ApiException(_friendlyNetworkError(e));
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Server returned an unexpected response (${res.statusCode}).',
        statusCode: res.statusCode,
      );
    }

    if (res.statusCode >= 400 || decoded['success'] == false) {
      final msg = decoded['message']?.toString() ??
          'Request failed (${res.statusCode}).';
      throw ApiException(msg, statusCode: res.statusCode);
    }

    return decoded;
  }

  String _friendlyNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('TimeoutException')) {
      return "Can't reach server at ${ApiConfig.baseUrl}. Make sure the backend is running.";
    }
    if (s.contains('SocketException') || s.contains('Connection refused')) {
      return "Can't connect to ${ApiConfig.baseUrl}. Check the API base URL and that the backend is running.";
    }
    return 'Network error: $s';
  }
}
