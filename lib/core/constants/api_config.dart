class ApiConfig {
  ApiConfig._();

  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
  ///
  /// Defaults:
  ///   • Android emulator → 10.0.2.2 maps to host's localhost
  ///   • iOS simulator    → 127.0.0.1 works
  ///   • Real device      → pass --dart-define with your machine's LAN IP
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.rp-vespera.cloud/api',
  );

  static const Duration timeout = Duration(seconds: 20);
}
