import 'dart:typed_data';

import '../../core/network/api_client.dart';
import '../../models/cinex_models.dart';

class PushResult {
  const PushResult({
    required this.operationId,
    required this.status,
    this.serverVersion,
    this.serverUpdatedAt,
    this.error,
    this.remotePayload,
    this.conflictingFields = const [],
  });

  final String operationId;
  final String status;
  final int? serverVersion;
  final DateTime? serverUpdatedAt;
  final String? error;
  final Map<String, dynamic>? remotePayload;
  final List<String> conflictingFields;

  factory PushResult.fromJson(Map<String, dynamic> json) {
    return PushResult(
      operationId: json['operationId'] as String,
      status: json['status'] as String,
      serverVersion: json['serverVersion'] as int?,
      serverUpdatedAt: _dateTimeOrNull(json['serverUpdatedAt']),
      error: json['error'] as String?,
      remotePayload: json['remotePayload'] as Map<String, dynamic>?,
      conflictingFields:
          (json['conflictingFields'] as List? ?? const [])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class PushResponse {
  const PushResponse({required this.results, this.nextCursor});

  final List<PushResult> results;
  final String? nextCursor;

  factory PushResponse.fromJson(Map<String, dynamic> json) {
    return PushResponse(
      results: (json['results'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PushResult.fromJson)
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class PullChange {
  const PullChange({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.serverVersion,
    required this.updatedAt,
    required this.payload,
  });

  final String entityType;
  final String entityId;
  final String operation;
  final int serverVersion;
  final DateTime updatedAt;
  final Map<String, dynamic> payload;

  factory PullChange.fromJson(Map<String, dynamic> json) {
    return PullChange(
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      operation: json['operation'] as String,
      serverVersion: json['serverVersion'] as int? ?? 0,
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
      payload: json['payload'] as Map<String, dynamic>? ?? const {},
    );
  }
}

class PullResponse {
  const PullResponse({
    required this.changes,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<PullChange> changes;
  final String? nextCursor;
  final bool hasMore;

  factory PullResponse.fromJson(Map<String, dynamic> json) {
    return PullResponse(
      changes: (json['changes'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PullChange.fromJson)
          .toList(),
      nextCursor: json['nextCursor'] as String?,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

class RemoteFileUpload {
  const RemoteFileUpload({
    required this.remoteUrl,
    this.checksum,
    this.fileSize,
    this.mimeType,
  });

  final String remoteUrl;
  final String? checksum;
  final int? fileSize;
  final String? mimeType;

  factory RemoteFileUpload.fromJson(Map<String, dynamic> json) {
    return RemoteFileUpload(
      remoteUrl: json['remoteUrl'] as String? ?? json['url'] as String? ?? '',
      checksum: json['checksum'] as String?,
      fileSize: json['fileSize'] as int?,
      mimeType: json['mimeType'] as String?,
    );
  }
}

abstract class RemoteDataSource {
  Future<AuthSession> login(String email, String password);

  Future<AuthSession> register(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  );

  Future<List<Map<String, dynamic>>> projectManifest();

  Future<PushResponse> push({
    required String deviceId,
    required String clientBatchId,
    required List<Map<String, dynamic>> operations,
  });

  Future<PullResponse> pull({String? cursor});

  Future<RemoteFileUpload> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  });
}

class ApiRemoteDataSource implements RemoteDataSource {
  ApiRemoteDataSource(this._client);

  final ApiClient _client;

  @override
  Future<AuthSession> login(String email, String password) async {
    final data = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<AuthSession> register(
    String displayName,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final data = await _client.post(
      '/auth/register',
      body: {
        'displayName': displayName,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Map<String, dynamic>>> projectManifest() async {
    final data = await _client.get('/projects/manifest');
    return (data as List? ?? const []).cast<Map<String, dynamic>>();
  }

  @override
  Future<PushResponse> push({
    required String deviceId,
    required String clientBatchId,
    required List<Map<String, dynamic>> operations,
  }) async {
    final data = await _client.post(
      '/sync/push',
      body: {
        'deviceId': deviceId,
        'clientBatchId': clientBatchId,
        'operations': operations,
      },
    );
    return PushResponse.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<PullResponse> pull({String? cursor}) async {
    final data = await _client.get('/sync/pull', query: {'cursor': cursor});
    return PullResponse.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RemoteFileUpload> uploadFile({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final data = await _client.multipart(
      '/files/upload',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    return RemoteFileUpload.fromJson(data as Map<String, dynamic>);
  }
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
