import 'package:droid_bridge/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BridgeApp extends StatelessWidget {
  const BridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const appleBlue = Color(0xFF007AFF);
    const darkBackground = Color(0xFF1E1E24);
    const darkSurface = Color(0xFF282830);
    const lightBackground = Color(0xFFF2F2F7);

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appleBlue,
        brightness: Brightness.dark,
        surface: darkSurface,
      ).copyWith(
        primary: appleBlue,
        secondary: const Color(0xFF34C759),
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0x1F2C2C35),
            width: 1,
          ),
        ),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: appleBlue,
        brightness: Brightness.dark,
      ),
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: appleBlue,
        brightness: Brightness.light,
        surface: Colors.white,
      ).copyWith(
        primary: appleBlue,
        secondary: const Color(0xFF34C759),
        surface: Colors.white,
        onSurface: const Color(0xFF1C1C1E),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: appleBlue,
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: 'Continuity Bridge',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const DashboardScreen(),
    );
  }
}
