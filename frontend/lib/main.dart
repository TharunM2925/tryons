import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/services/api_service.dart';
import 'features/tattoo_upload/tattoo_provider.dart';
import 'features/camera_tryon/tryon_provider.dart';
import 'features/history/history_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProxyProvider<ApiService, TattooProvider>(
          create: (ctx) => TattooProvider(ctx.read<ApiService>()),
          update: (_, api, prev) => prev ?? TattooProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiService, TryOnProvider>(
          create: (ctx) => TryOnProvider(ctx.read<ApiService>()),
          update: (_, api, prev) => prev ?? TryOnProvider(api),
        ),
        ChangeNotifierProxyProvider<ApiService, HistoryProvider>(
          create: (ctx) => HistoryProvider(ctx.read<ApiService>()),
          update: (_, api, prev) => prev ?? HistoryProvider(api),
        ),
      ],
      child: const InkVisionApp(),
    ),
  );
}
