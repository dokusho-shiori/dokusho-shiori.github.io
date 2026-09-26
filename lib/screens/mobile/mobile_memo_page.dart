import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_theme.dart';
import '../../utils/responsive_nav.dart';
import '../book_detail_screen.dart';

/// メモタブ：本ごとのメモ件数を一覧表示し、タップで本の詳細（メモ一覧・追加）へ。
class MobileMemoPage extends StatelessWidget {
  const MobileMemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('メモ', style: MobileTheme.heading(fontSize: 20)),
            ),
            Expanded(
              child: StreamBuilder<List<Book>>(
                stream: FirestoreService().booksStream(),
                builder: (context, snapshot) {
                  final books = snapshot.data ?? [];
                  if (books.isEmpty) {
                    return Center(
                      child: Text('本を登録するとここにメモが表示されます',
                        style: MobileTheme.body(fontSize: 13, color: MobileTheme.textSub)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _MemoBookRow(book: books[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoBookRow extends StatelessWidget {
  final Book book;
  const _MemoBookRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return GestureDetector(
      onTap: () => pushResponsive(context, BookDetailScreen(book: book)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: MobileTheme.cardDecoration(radius: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 42, height: 58,
                child: book.thumbnail != null
                    ? Image.network(book.thumbnail!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: MobileTheme.body(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  if (book.author.isNotEmpty)
                    Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: MobileTheme.body(fontSize: 12, color: MobileTheme.textSub)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (uid != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users').doc(uid)
                    .collection('books').doc(book.id)
                    .collection('memos')
                    .snapshots(),
                builder: (context, snap) {
                  final count = snap.data?.docs.length ?? 0;
                  return Container(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: MobileTheme.navSelectedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$count件', style: MobileTheme.body(
                      fontSize: 12, fontWeight: FontWeight.w700, color: MobileTheme.navSelectedText)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    color: MobileTheme.cardBorder,
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 16))));
}
