import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../errors/app_exception.dart';
import '../storage/token_storage.dart';

class ApiClient {
  ApiClient(this.baseUrl, this._tokenStorage, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage _tokenStorage;
  final http.Client _http;
  void Function()? onUnauthorized;

  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const {},
    Duration timeout = const Duration(seconds: 20),
  }) {
    return _send('GET', path, query: query, timeout: timeout);
  }

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<Uint8List> getBytes(String path) async {
    final request = http.Request('GET', _uri(path));
    await _authorize(request.headers);
    final response =
        await _http.send(request).timeout(const Duration(seconds: 30));
    final bytes = await response.stream.toBytes();
    if (response.statusCode == 401) {
      await _tokenStorage.clear();
      onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException('Không thể tải tệp', statusCode: response.statusCode);
    }
    return bytes;
  }

  Future<dynamic> multipart(
    String path, {
    required String fieldName,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    await _authorize(request.headers);
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: MediaType.parse(contentType),
      ),
    );
    final streamed =
        await _http.send(request).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?> query = const {},
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final request = http.Request(method, _uri(path, query));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    await _authorize(request.headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final streamed = await _http.send(request).timeout(timeout);
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<void> _authorize(Map<String, String> headers) async {
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
  }

  Uri _uri(String path, [Map<String, Object?> query = const {}]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final params = <String, String>{};
    query.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        params[key] = value.toString();
      }
    });
    return Uri.parse(
      '$baseUrl$normalized',
    ).replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<dynamic> _decode(http.Response response) async {
    final text = utf8.decode(response.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode == 401) {
      await _tokenStorage.clear();
      onUnauthorized?.call();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (json is Map<String, dynamic>) {
        final errors = (json['errors'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            {};
        throw AppException(
          json['message']?.toString() ?? 'Yêu cầu thất bại',
          statusCode: response.statusCode,
          code: json['code']?.toString(),
          errors: errors,
        );
      }
      throw AppException('Yêu cầu thất bại', statusCode: response.statusCode);
    }
    if (json is Map<String, dynamic> && json.containsKey('data')) {
      return json['data'];
    }
    return json;
  }
}
