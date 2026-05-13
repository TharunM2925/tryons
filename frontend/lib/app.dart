import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_routes.dart';
import 'features/splash/splash_screen.dart';

class InkVisionApp extends StatelessWidget {
  const InkVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InkVision AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const SplashScreen(),
      ),
    );
  }
}
