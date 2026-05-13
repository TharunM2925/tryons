/// App-wide constants for InkVision AI.
class AppConstants {
  // ── API ────────────────────────────────────────────────────────────────
  /// Backend base URL. Change to your server IP for device testing.
  /// Android emulator uses 10.0.2.2 to reach host machine localhost.
  static const String baseUrl = 'http://localhost:8000';
  // For Android Emulator use: static const String baseUrl = 'http://10.0.2.2:8000';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ── Upload ─────────────────────────────────────────────────────────────
  static const int maxFileSizeMb = 10;
  static const List<String> allowedExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  // ── Camera ─────────────────────────────────────────────────────────────
  /// How many milliseconds between sending frames to backend for detection.
  static const int frameProcessIntervalMs = 1500;

  // ── Tattoo Overlay Defaults ────────────────────────────────────────────
  static const double defaultTattooOpacity = 0.9;
  static const double defaultTattooScale = 0.7;
  static const double minTattooScale = 0.1;
  static const double maxTattooScale = 5.0;

  // ── Branding ──────────────────────────────────────────────────────────
  static const String appName = 'InkVision AI';
  static const String appTagline = 'Wear Your Ink Before You Ink';
}
