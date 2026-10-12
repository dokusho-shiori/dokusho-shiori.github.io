import 'package:flutter/material.dart';

/// スマホ用レイアウト（幅600px未満）専用の配色・フォント定義。
/// PC版（AppTheme）には影響しない。
class MobileTheme {
  static const Color bg           = Color(0xFFF6F0E4);
  static const Color card         = Color(0xFFFFFDF8);
  static const Color cardBorder   = Color(0xFFE4D9C3);
  static const Color dark         = Color(0xFF1C130B);
  static const Color goldLine     = Color(0xFFA8790F);
  static const Color goldLogo     = Color(0xFFD4A62A);
  static const Color goldOnDark   = Color(0xFFF2D98A);
  static const Color textBody     = Color(0xFF2A1D12);
  static const Color textSub      = Color(0xFF6B5B48);

  // イラスト用
  static const Color illustGreen   = Color(0xFF4E7F5E);
  static const Color illustBlue    = Color(0xFF2F5B9A);
  static const Color illustMustard = Color(0xFFB8860B);
  static const Color illustBrown   = Color(0xFF8B4A1F);

  // ナビゲーションバー
  static const Color navSelectedBg   = Color(0xFFF2E4BD);
  static const Color navSelectedText = Color(0xFF7A5608);

  static const String serifFont = 'Shippori Mincho';
  static const String sansFont  = 'Zen Kaku Gothic New';
  static const List<String> _serifFallback = ['Hiragino Mincho ProN', 'serif'];
  static const List<String> _sansFallback  = ['Hiragino Sans', 'sans-serif'];

  static TextStyle heading({
    double fontSize = 18,
    Color color = dark,
    FontWeight fontWeight = FontWeight.w700,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: serifFont,
    fontFamilyFallback: _serifFallback,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle body({
    double fontSize = 14,
    Color color = textBody,
    FontWeight fontWeight = FontWeight.w400,
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: sansFont,
    fontFamilyFallback: _sansFallback,
    fontSize: fontSize,
    color: color,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );

  static BoxDecoration cardDecoration({double radius = 20}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: cardBorder),
  );
}
