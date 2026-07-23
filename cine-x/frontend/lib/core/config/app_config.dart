class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'CINEX_API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );
}
