import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs du club
  static const Color bleuMarine = Color(0xFF0F2C4C);
  static const Color bleuClair = Color(0xFF4DA6FF);
  static const Color dore = Color(0xFFD4AF37);

  // Le thème global de l'application
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      colorScheme: ColorScheme.fromSeed(
        seedColor: bleuMarine,
        primary: bleuMarine,
        secondary: dore,
        tertiary: bleuClair,
        background: Colors.grey[50],
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bleuMarine,
          foregroundColor: dore,
        ),
      ),
    );
  }
}