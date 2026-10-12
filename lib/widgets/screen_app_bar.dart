import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/mobile_theme.dart';
import '../utils/breakpoint.dart';

/// 本の詳細・登録・メモ入力・設定などの画面の上に出すタイトルバー。
///
/// PC：これまでどおりの濃い色のバー。
/// スマホ：外枠の固定ヘッダーの下（枠の中）に入るので、
///         二重のヘッダーに見えないよう、細くて明るい色の見出しバーにする。
///
/// [closeButton] が true のときは左上を「閉じる」×に、false のときは「戻る」矢印にする。
/// [actionLabel] を渡すと右上に文字のボタン（「保存する」など）を出す。
PreferredSizeWidget buildScreenAppBar(
  BuildContext context, {
  required String title,
  bool closeButton = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final mobile = isMobileLayout(context);
  final fg = mobile ? MobileTheme.textBody : Colors.white;
  return AppBar(
    backgroundColor: mobile ? MobileTheme.bg : AppTheme.headerBg,
    surfaceTintColor: mobile ? Colors.transparent : null,
    scrolledUnderElevation: mobile ? 0 : null,
    toolbarHeight: mobile ? 48 : null,
    shape: mobile
        ? const Border(bottom: BorderSide(color: MobileTheme.cardBorder))
        : null,
    leading: closeButton ? CloseButton(color: fg) : null,
    iconTheme: IconThemeData(color: fg),
    title: Text(title,
      style: TextStyle(
        color: fg, fontSize: mobile ? 16 : 18, fontWeight: FontWeight.w700)),
    actions: actionLabel == null
        ? null
        : [
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel,
                style: TextStyle(
                  color: mobile ? MobileTheme.navSelectedText : AppTheme.gold,
                  fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
  );
}
