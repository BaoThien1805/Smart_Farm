import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;
  const ApiException(this.message, [this.status, this.code]);
  @override
  String toString() => message;
}

class ApiClient {
  // Override API_URL explicitly when testing against a local backend.
  static const defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://smart-farm-api-4n6x.onrender.com/api',
  );
  final http.Client client;
  final String baseUrl;
  final Duration requestTimeout;
  String? token;
  VoidCallback? onUnauthorized;

  ApiClient({http.Client? client, String? baseUrl, Duration? requestTimeout})
    : client = client ?? http.Client(),
      requestTimeout =
          requestTimeout ??
          Duration(
            seconds: (baseUrl ?? defaultBaseUrl).startsWith('https://')
                ? 90
                : 15,
          ),
      baseUrl = baseUrl ?? defaultBaseUrl;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'));
      request.headers['Accept'] = 'application/json';
      if (authenticated && token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(requestTimeout);
      if (response.statusCode == 401 && authenticated) onUnauthorized?.call();
      Map<String, dynamic> data;
      try {
        final decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected a JSON object');
        }
        data = decoded;
      } on FormatException {
        if (response.statusCode >= 400) {
          throw ApiException(
            httpErrorMessage(response.statusCode),
            response.statusCode,
          );
        }
        throw const ApiException(
          'Máy chủ không trả dữ liệu API dạng JSON. Kiểm tra địa chỉ API và cấu hình triển khai.',
        );
      }
      if (response.statusCode >= 400) {
        final serverError = data['error'];
        final message = serverError is Map<String, dynamic>
            ? serverError['message']
            : null;
        throw ApiException(
          message is String && message.trim().isNotEmpty
              ? message
              : httpErrorMessage(response.statusCode),
          response.statusCode,
          serverError is Map<String, dynamic> && serverError['code'] is String
              ? serverError['code'] as String
              : null,
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'Chưa nhận được phản hồi từ máy chủ. Máy chủ có thể đang khởi động; vui lòng thử lại.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Không kết nối được máy chủ. Kiểm tra kết nối và thử lại.',
      );
    } on FormatException {
      throw const ApiException(
        'Phản hồi máy chủ không hợp lệ. Vui lòng thử lại.',
      );
    }
  }

  void dispose() => client.close();

  static String httpErrorMessage(int status) => switch (status) {
    404 => 'Không tìm thấy API (HTTP 404). Kiểm tra Primary URL trên Render và cấu hình địa chỉ API.',
    401 => 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
    502 || 503 || 504 =>
      'Máy chủ chưa sẵn sàng (HTTP $status). Đợi khởi động hoặc kiểm tra deployment trên Render.',
    _ => 'Yêu cầu thất bại (HTTP $status). Vui lòng thử lại.',
  };
}
