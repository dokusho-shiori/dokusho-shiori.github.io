import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_theme.dart';
import '../../utils/cover_image.dart';

class MobileHomePage extends StatelessWidget {
  final void Function(String filter) onOpenBookshelf;
  final void Function(Book book) onOpenBookDetail;

  const MobileHomePage({
    super.key,
    required this.onOpenBookshelf,
    required this.onOpenBookDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.bg,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<Book>>(
              stream: FirestoreService().booksStream(),
              builder: (context, snapshot) {
                final books = snapshot.data ?? [];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  children: [
                    _ReadingSection(
                      books: books,
                      onSeeAll: () => onOpenBookshelf('reading'),
                      onPickFromShelf: () => onOpenBookshelf('all'),
                      onOpenBookDetail: onOpenBookDetail,
                    ),
                    const SizedBox(height: 28),
                    _ShelfCountsSection(books: books, onOpenBookshelf: onOpenBookshelf),
                    const SizedBox(height: 28),
                    _RecentMemosSection(books: books, onOpenBookDetail: onOpenBookDetail),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        color: MobileTheme.dark,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/shiori_logo.png',
            width: 32, height: 32, fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionHeading({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: MobileTheme.heading(fontSize: 18)),
        const Spacer(),
        if (actionLabel != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerRight,
                child: Text(actionLabel!,
                  style: MobileTheme.body(fontSize: 12, color: MobileTheme.goldLine, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadingSection extends StatelessWidget {
  final List<Book> books;
  final VoidCallback onSeeAll;
  final VoidCallback onPickFromShelf;
  final void Function(Book book) onOpenBookDetail;

  const _ReadingSection({
    required this.books,
    required this.onSeeAll,
    required this.onPickFromShelf,
    required this.onOpenBookDetail,
  });

  @override
  Widget build(BuildContext context) {
    final reading = books.where((b) => b.status == 'reading').toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: '読み中', actionLabel: 'すべて見る', onAction: onSeeAll),
        const SizedBox(height: 12),
        if (reading.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: MobileTheme.cardDecoration(),
            child: Column(
              children: [
                Text('読み中の本はまだありません',
                  style: MobileTheme.body(fontSize: 13, color: MobileTheme.textSub)),
                const SizedBox(height: 12),
                Material(
                  color: MobileTheme.dark,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onPickFromShelf,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text('本棚から選ぶ', style: MobileTheme.body(
                        fontSize: 13, color: MobileTheme.goldOnDark, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: reading.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _ReadingCard(
                book: reading[i],
                onTap: () => onOpenBookDetail(reading[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  const _ReadingCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 132, height: 172,
                child: book.thumbnail != null
                    ? CoverNetworkImage(url: book.thumbnail!, fit: BoxFit.cover,
                        placeholderBuilder: (_) => _placeholder())
                    : _placeholder(),
              ),
            ),
            const SizedBox(height: 6),
            Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: MobileTheme.body(fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(uid)
                    .collection('books').doc(book.id)
                    .collection('memos')
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Text('メモ $count件',
                    style: MobileTheme.body(fontSize: 10, color: MobileTheme.textSub));
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: MobileTheme.cardBorder,
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 22))));
}

class _ShelfCountsSection extends StatelessWidget {
  final List<Book> books;
  final void Function(String filter) onOpenBookshelf;
  const _ShelfCountsSection({required this.books, required this.onOpenBookshelf});

  int _count(String status) => books.where((b) => b.status == status).length;

  @override
  Widget build(BuildContext context) {
    const tiles = [
      {'key': 'reading', 'label': '読み中', 'emoji': '📖'},
      {'key': 'wish', 'label': '読みたい', 'emoji': '🌙'},
      {'key': 'stack', 'label': '積読', 'emoji': '📚'},
      {'key': 'done', 'label': '読了', 'emoji': '✅'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: '本棚'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: tiles.map((t) {
            final key = t['key']!;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onOpenBookshelf(key),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: MobileTheme.cardDecoration(radius: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t['emoji']!, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_count(key)}', style: MobileTheme.body(
                            fontSize: 18, fontWeight: FontWeight.w700, color: MobileTheme.textBody)),
                          const SizedBox(height: 2),
                          Text(t['label']!, style: MobileTheme.body(
                            fontSize: 11, color: MobileTheme.textSub)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RecentMemo {
  final Book book;
  final String content;
  final DateTime createdAt;
  _RecentMemo({required this.book, required this.content, required this.createdAt});
}

class _RecentMemosSection extends StatefulWidget {
  final List<Book> books;
  final void Function(Book book) onOpenBookDetail;
  const _RecentMemosSection({required this.books, required this.onOpenBookDetail});

  @override
  State<_RecentMemosSection> createState() => _RecentMemosSectionState();
}

class _RecentMemosSectionState extends State<_RecentMemosSection> {
  late Future<List<_RecentMemo>> _future = _load();

  @override
  void didUpdateWidget(covariant _RecentMemosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 本の一覧（更新日時など）が変わったときだけ再取得する
    final oldIds = oldWidget.books.map((b) => '${b.id}:${b.updatedAt}').join(',');
    final newIds = widget.books.map((b) => '${b.id}:${b.updatedAt}').join(',');
    if (oldIds != newIds) {
      _future = _load();
    }
  }

  Future<List<_RecentMemo>> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.books.isEmpty) return [];

    // 負荷を抑えるため、直近で更新された本に絞って最新メモを1件ずつ取得する
    final candidates = [...widget.books]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final targets = candidates.take(15).toList();

    final results = <_RecentMemo>[];
    for (final book in targets) {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('books').doc(book.id)
          .collection('memos')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        results.add(_RecentMemo(
          book: book,
          content: data['content'] as String? ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? book.updatedAt,
        ));
      }
    }
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RecentMemo>>(
      future: _future,
      builder: (context, snapshot) {
        final memos = snapshot.data ?? [];
        if (memos.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(title: '最近のメモ'),
            const SizedBox(height: 12),
            ...memos.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => widget.onOpenBookDetail(m.book),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: MobileTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: MobileTheme.body(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(m.content, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: MobileTheme.body(fontSize: 12, color: MobileTheme.textSub, height: 1.5)),
                    ],
                  ),
                ),
              ),
            )),
          ],
        );
      },
    );
  }
}
