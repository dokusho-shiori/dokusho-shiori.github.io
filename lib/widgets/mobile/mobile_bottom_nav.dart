import 'package:flutter/material.dart';
import '../../theme/mobile_theme.dart';

enum MobileTab { home, bookshelf, memo, menu }

class MobileBottomNav extends StatelessWidget {
  final MobileTab current;
  final ValueChanged<MobileTab> onSelect;
  final VoidCallback onRegister;

  const MobileBottomNav({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: MobileTheme.card,
        border: Border(top: BorderSide(color: MobileTheme.cardBorder)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Row(
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'ホーム',
                  selected: current == MobileTab.home,
                  onTap: () => onSelect(MobileTab.home),
                ),
                _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: '本棚',
                  selected: current == MobileTab.bookshelf,
                  onTap: () => onSelect(MobileTab.bookshelf),
                ),
                // 中央：登録ボタンのラベル（実体の丸ボタンは上にPositionedで重ねて浮かせる）
                const Expanded(child: _RegisterLabelSlot()),
                _NavItem(
                  icon: Icons.edit_note_rounded,
                  label: 'メモ',
                  selected: current == MobileTab.memo,
                  onTap: () => onSelect(MobileTab.memo),
                ),
                _NavItem(
                  icon: Icons.menu_rounded,
                  label: 'メニュー',
                  selected: current == MobileTab.menu,
                  onTap: () => onSelect(MobileTab.menu),
                ),
              ],
            ),
            Positioned(
              top: -12,
              child: _RegisterButton(onTap: onRegister),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? MobileTheme.navSelectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? MobileTheme.navSelectedText : MobileTheme.textSub,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: MobileTheme.body(
                    fontSize: 11,
                    color: selected ? MobileTheme.navSelectedText : MobileTheme.textSub,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterLabelSlot extends StatelessWidget {
  const _RegisterLabelSlot();

  @override
  Widget build(BuildContext context) {
    // 上の丸ボタン（Positionedで浮かせている実体）の高さぶんだけ空けて、
    // ラベルの位置を他の項目と同じ行に揃える。
    return SizedBox(
      height: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          const SizedBox(height: 2),
          Text(
            '登録',
            style: MobileTheme.body(
              fontSize: 11,
              color: MobileTheme.navSelectedText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RegisterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MobileTheme.dark,
            shape: BoxShape.circle,
            border: Border.all(color: MobileTheme.goldLine, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: MobileTheme.goldOnDark, size: 24),
        ),
      ),
    );
  }
}
