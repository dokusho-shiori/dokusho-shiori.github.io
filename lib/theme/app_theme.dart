import 'package:flutter/material.dart';

class AppTheme {
  // 栞カラーパレット
  static const Color headerBg    = Color(0xFF1A1006);
  static const Color tabBg       = Color(0xFF2C1F0A);
  static const Color gold        = Color(0xFFB8860B);
  static const Color goldLight   = Color(0xFFC9981A);
  static const Color bg          = Color(0xFFF5F0E8);
  static const Color bg2         = Color(0xFFEDE8DC);
  static const Color cardBg      = Color(0xFFFAF7F0);
  static const Color textPrimary = Color(0xFF2C1F0A);
  static const Color textSecondary = Color(0xFF7A6A50);
  static const Color border      = Color(0xFFD4C9B0);
  static const Color tagBg       = Color(0xFFE8E0D0);
  static const Color progressFill = Color(0xFF2C7A4B);
  static const Color btnRegister = Color(0xFF1A1006);
  static const Color btnMemo     = Color(0xFF8B3A2A);
  static const Color btnSearch   = Color(0xFF2A3D4F);

  // ステータスカラー（デフォルト）
  static const Color readingBar  = Color(0xFF000000);
  static const Color wishBar     = Color(0xFFE74C3C);
  static const Color stackBar    = Color(0xFF27AE60);
  static const Color doneBar     = Color(0xFF888888);

  // 後方互換用
  static const Color primary      = headerBg;
  static const Color primaryLight = gold;
  static const Color accent       = goldLight;
  static const Color background   = bg;
  static const Color surface      = cardBg;

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'sans-serif',
      colorScheme: ColorScheme.fromSeed(
        seedColor: headerBg,
        brightness: Brightness.light,
      ).copyWith(
        primary: headerBg,
        secondary: gold,
        surface: cardBg,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: headerBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: gold,
        unselectedLabelColor: Color(0xFF888888),
        indicatorColor: gold,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: btnMemo,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnMemo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
