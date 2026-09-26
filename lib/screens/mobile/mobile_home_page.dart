import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_theme.dart';

class MobileHomePage extends StatelessWidget {
  final VoidCallback onOpenBookshelf;
  final VoidCallback onOpenRegisterBook;
  final VoidCallback onOpenMemoTab;
  final VoidCallback onOpenMenu;
  final void Function(Book book) onWriteMemoFor;

  const MobileHomePage({
    super.key,
    required this.onOpenBookshelf,
    required this.onOpenRegisterBook,
    required this.onOpenMemoTab,
    required this.onOpenMenu,
    required this.onWriteMemoFor,
  });

  Future<void> _openSite() async {
    final uri = Uri.parse('https://dokusho-shiori.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.bg,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _TopBlock(onTap: _openSite),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('よく使う機能', style: MobileTheme.heading(fontSize: 18)),
                const Spacer(),
                Text('タップして開く',
                  style: MobileTheme.body(fontSize: 12, color: MobileTheme.textSub)),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _QuickCard(
                  icon: Icons.menu_book_rounded,
                  color: MobileTheme.illustBrown,
                  title: '本棚',
                  subtitle: '読み中・積読・読了',
                  onTap: onOpenBookshelf,
                ),
                _QuickCard(
                  icon: Icons.add_box_rounded,
                  color: MobileTheme.illustGreen,
                  title: '本を登録',
                  subtitle: '検索・バーコード',
                  onTap: onOpenRegisterBook,
                ),
                _QuickCard(
                  icon: Icons.edit_note_rounded,
                  color: MobileTheme.illustBlue,
                  title: 'メモ',
                  subtitle: '引用・感想',
                  onTap: onOpenMemoTab,
                ),
                _QuickCard(
                  icon: Icons.settings_rounded,
                  color: MobileTheme.illustMustard,
                  title: 'その他',
                  subtitle: '設定・使い方',
                  onTap: onOpenMenu,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _CurrentlyReadingSection(onWriteMemoFor: onWriteMemoFor),
          ],
        ),
      ),
    );
  }
}

class _TopBlock extends StatelessWidget {
  final VoidCallback onTap;
  const _TopBlock({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MobileTheme.dark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('栞', style: TextStyle(
              fontSize: 40, color: MobileTheme.goldLogo,
              fontWeight: FontWeight.w900, fontFamily: 'serif')),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('栞', style: MobileTheme.heading(
                  fontSize: 26, color: MobileTheme.goldLogo, fontWeight: FontWeight.w800)),
                Text('SHIORI', style: MobileTheme.body(
                  fontSize: 11, color: MobileTheme.goldOnDark, letterSpacing: 4)),
                const SizedBox(height: 4),
                Text('読書管理', style: MobileTheme.body(
                  fontSize: 13, color: MobileTheme.goldOnDark.withValues(alpha: 0.85))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: const EdgeInsets.all(16),
          decoration: MobileTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const Spacer(),
              Text(title, style: MobileTheme.body(
                fontSize: 15, fontWeight: FontWeight.w700, color: MobileTheme.textBody)),
              const SizedBox(height: 2),
              Text(subtitle, style: MobileTheme.body(
                fontSize: 11, color: MobileTheme.textSub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentlyReadingSection extends StatelessWidget {
  final void Function(Book book) onWriteMemoFor;
  const _CurrentlyReadingSection({required this.onWriteMemoFor});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Book>>(
      stream: FirestoreService().booksStream(),
      builder: (context, snapshot) {
        final books = snapshot.data ?? [];
        final reading = books.where((b) => b.status == 'reading').toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (reading.isEmpty) return const SizedBox();
        final book = reading.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('いま読んでる本', style: MobileTheme.heading(fontSize: 18)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: MobileTheme.cardDecoration(),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 52, height: 74,
                      child: book.thumbnail != null
                          ? Image.network(book.thumbnail!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _coverPlaceholder())
                          : _coverPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: MobileTheme.body(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        if (book.author.isNotEmpty)
                          Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: MobileTheme.body(fontSize: 12, color: MobileTheme.textSub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: MobileTheme.dark,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: () => onWriteMemoFor(book),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        child: Text('メモを書く', style: MobileTheme.body(
                          fontSize: 12, color: MobileTheme.goldOnDark, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _coverPlaceholder() => Container(
    color: MobileTheme.cardBorder,
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 20))));
}
