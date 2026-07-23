class AppException implements Exception {
  AppException(
    this.message, {
    this.statusCode,
    this.code,
    this.errors = const {},
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String> errors;

  @override
  String toString() => message;
}
