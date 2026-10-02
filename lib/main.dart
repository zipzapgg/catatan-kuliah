import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'providers/app_provider.dart';
import 'services/notification_service.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (error) {
    debugPrint('Pengingat belum tersedia: $error');
  }

  // Aktifkan refresh rate tertinggi (120Hz/90Hz) jika hardware HP mendukung
  if (!kIsWeb && Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {
      // Fallback jika tidak didukung
    }
  }

  final appProvider = AppProvider();

  runApp(CollegeTaskApp(provider: appProvider));
}

class CollegeTaskApp extends StatelessWidget {
  final AppProvider provider;
  static final _lightTheme = AppTheme.lightTheme();
  static final _darkTheme = AppTheme.darkTheme();

  const CollegeTaskApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      child: DashboardScreen(provider: provider),
      builder: (context, child) {
        return MaterialApp(
          title: 'Catatan Tugas Kuliah',
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: child,
        );
      },
    );
  }
}
