import 'package:flutter/material.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/tattoo_upload/tattoo_upload_screen.dart';
import '../../features/camera_tryon/camera_tryon_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/settings/settings_screen.dart';

import '../../features/tattoo_upload/tattoo_gallery_screen.dart';

/// Centralized route definitions for InkVision AI.
class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String tattooUpload = '/tattoo-upload';
  static const String tattooGallery = '/tattoo-gallery';
  static const String cameraTryOn = '/camera-tryon';
  static const String history = '/history';
  static const String settings = '/settings';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    home: (_) => const HomeScreen(),
    tattooUpload: (_) => const TattooUploadScreen(),
    tattooGallery: (_) => const TattooGalleryScreen(),
    cameraTryOn: (_) => const CameraTryOnScreen(),
    history: (_) => const HistoryScreen(),
    settings: (_) => const SettingsScreen(),
  };
}
