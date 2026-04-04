import 'package:droid_bridge/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';

class BridgeApp extends StatelessWidget {
  const BridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const sand = Color(0xFFF6F1E8);
    const ink = Color(0xFF132238);
    const coral = Color(0xFFE9715F);
    const teal = Color(0xFF2E7D7A);

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
        surface: sand,
      ).copyWith(
        primary: teal,
        secondary: coral,
        surface: sand,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: sand,
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: ink,
            displayColor: ink,
          ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: ink.withValues(alpha: 0.08),
          ),
        ),
      ),
    );

    return MaterialApp(
      title: 'Droid Bridge',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const DashboardScreen(),
    );
  }
}
