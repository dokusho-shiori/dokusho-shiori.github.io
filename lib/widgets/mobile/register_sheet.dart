import 'package:flutter/material.dart';
import '../../theme/mobile_theme.dart';

/// 登録ボタン（中央ボタン）をタップしたときに出す下からのシート。
/// 「本を登録」「メモを追加」の2択＋閉じるボタン。背景は自動で暗くなる。
Future<void> showRegisterSheet(
  BuildContext context, {
  required VoidCallback onRegisterBook,
  required VoidCallback onAddMemo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).padding.bottom + 16,
        left: 20, right: 20, top: 8,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MobileTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MobileTheme.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: MobileTheme.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _SheetBigButton(
              icon: Icons.menu_book_rounded,
              label: '本を登録',
              onTap: () {
                Navigator.pop(sheetContext);
                onRegisterBook();
              },
            ),
            const SizedBox(height: 12),
            _SheetBigButton(
              icon: Icons.edit_note_rounded,
              label: 'メモを追加',
              onTap: () {
                Navigator.pop(sheetContext);
                onAddMemo();
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text('閉じる', style: MobileTheme.body(
                  fontSize: 15, color: MobileTheme.textSub, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetBigButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetBigButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MobileTheme.dark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MobileTheme.goldLine, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: MobileTheme.goldOnDark, size: 22),
              const SizedBox(width: 12),
              Text(label, style: MobileTheme.body(
                fontSize: 16, color: MobileTheme.goldOnDark, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
