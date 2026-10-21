import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_colors.dart';
import 'screens/splash_screen.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/inter/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Inter font'], license);
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// SF Pro (the system font) on Apple devices; SF Pro may only be used on
  /// Apple platforms, so everywhere else we use Inter, its closest match.
  static String? get _fontFamily => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => null,
    _ => 'Inter',
  };

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crystal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: AppColors.primary),
        fontFamily: _fontFamily,
      ),
      home: const SplashScreen(),
    );
  }
}
