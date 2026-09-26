import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_nav.dart';
import 'book_form_screen.dart';
import 'memo_form_screen.dart';

class BookDetailScreen extends StatelessWidget {
  final Book book;
  const BookDetailScreen({super.key, required this.book});

  String _statusLabel(String status) {
    switch (status) {
      case 'reading': return '📖 読み中';
      case 'wish':    return '🌙 読みたい';
      case 'stack':   return '📚 積読';
      case 'done':    return '✅ 読了';
      default:        return '';
    }
  }

  String? _toIsbn10(String? isbn) {
    if (isbn == null) return null;
    final clean = isbn.replaceAll(RegExp(r'[^0-9X]'), '');
    if (clean.length == 10) return clean;
    if (clean.length != 13 || !clean.startsWith('978')) return null;
    final nine = clean.substring(3, 12);
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(nine[i]) * (10 - i);
    }
    final rem = (11 - (sum % 11)) % 11;
    final check = rem == 10 ? 'X' : rem.toString();
    return nine + check;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reading': return AppTheme.readingBar;
      case 'wish':    return AppTheme.wishBar;
      case 'stack':   return AppTheme.stackBar;
      case 'done':    return AppTheme.doneBar;
      default:        return AppTheme.doneBar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && book.id.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('books').doc(book.id)
            .snapshots(),
        builder: (context, snapshot) {
          final current = (snapshot.hasData && snapshot.data!.exists)
              ? Book.fromMap(book.id, snapshot.data!.data()!)
              : book;
          return _buildScaffold(context, current);
        },
      );
    }
    return _buildScaffold(context, book);
  }

  Widget _buildScaffold(BuildContext context, Book b) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBg,
        title: const Text('本の詳細',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: [
          // カバー＋タイトルエリア
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 90, height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8, offset: const Offset(2, 3))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: b.thumbnail != null
                      ? Image.network(b.thumbnail!, fit: BoxFit.cover,
                          key: ValueKey(b.thumbnail),
                          errorBuilder: (_, __, ___) => _Cover())
                      : _Cover(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title,
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary, height: 1.4)),
                    if (b.author.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(b.author,
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    ],
                    if (b.publisher.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(b.publisher,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(b.status).withValues(alpha: 0.15),
                        border: Border.all(color: _statusColor(b.status), width: 1),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(_statusLabel(b.status),
                        style: TextStyle(fontSize: 13, color: _statusColor(b.status),
                          fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_toIsbn10(b.isbn) != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(
                    'https://www.amazon.co.jp/dp/${_toIsbn10(b.isbn)}?tag=digitalhack-22');
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB8860B),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Amazonで見る',
                  style: TextStyle(fontSize: 14, color: Colors.white,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // ④ 編集画面の順番に合わせる
          // ISBN / ASIN
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('書誌情報',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                _InfoRow(label: 'タイトル', value: b.title),
                _InfoRow(label: '著者名', value: b.author.isNotEmpty ? b.author : null),
                _InfoRow(label: '出版社', value: b.publisher.isNotEmpty ? b.publisher : null),
                _InfoRow(label: '総ページ数', value: b.totalPages > 0 ? '${b.totalPages} ページ' : null),
                _InfoRow(label: '金額', value: b.price > 0 ? '¥${b.price}' : null),
                _InfoRow(label: '読書状態', value: _statusLabel(b.status)),
                if (b.status == 'reading')
                  _InfoRow(label: '現在のページ', value: b.currentPage > 0 ? 'p.${b.currentPage}' : null),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 読書進捗（読み中のみ）
          if (b.status == 'reading' && b.totalPages > 0) ...[
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('読書進捗',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                      Text('p.${b.currentPage} / ${b.totalPages}（${(b.progress * 100).round()}%）',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: b.progress,
                      backgroundColor: const Color(0xFFD4C9B0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.progressFill),
                      minHeight: 8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // タグ
          if (b.tags.isNotEmpty) ...[
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('タグ',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 6,
                    children: b.tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.tagBg,
                        border: Border.all(color: const Color(0xFFC9B890)),
                        borderRadius: BorderRadius.circular(14)),
                      child: Text(t,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // メモ・備考
          if (b.memo != null && b.memo!.isNotEmpty) ...[
            _Section(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('メモ・備考',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Text(b.memo!,
                    style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary, height: 1.6)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 購入場所・購入日・読み始め
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('購入情報',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                _InfoRow(label: '購入場所', value: b.purchaseLocation),
                _InfoRow(label: '購入日', value: b.buyDate),
                _InfoRow(label: '読み始めた日', value: b.startDate),
                _InfoRow(label: '読み終えた日', value: b.endDate),
                _InfoRow(label: 'ISBN', value: b.isbn),
                _InfoRow(label: 'ASIN', value: b.asin),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 読書メモ一覧（Firestore）
          _MemoList(book: b),
          const SizedBox(height: 32),

          // 戻る・編集ボタン
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('戻る',
                    style: TextStyle(fontSize: 16, color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => pushResponsive(context, BookFormScreen(book: b)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.btnMemo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('編集',
                    style: TextStyle(fontSize: 16, color: Colors.white,
                      fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFD4C9B0),
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 36))));
}

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 4, offset: const Offset(0, 1))],
    ),
    child: child,
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  const _InfoRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
          Expanded(
            child: Text(value!,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _MemoList extends StatefulWidget {
  final Book book;
  const _MemoList({required this.book});

  @override
  State<_MemoList> createState() => _MemoListState();
}

class _MemoListState extends State<_MemoList> {
  // ローカルで順序を保持しドラッグ後のチラつきを防ぐ
  List<QueryDocumentSnapshot> _sortedMemos = [];
  bool _isReordering = false;

  static List<QueryDocumentSnapshot> _sortMemos(List<QueryDocumentSnapshot> list) {
    final sorted = List<QueryDocumentSnapshot>.from(list);
    sorted.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aPage = int.tryParse(aData['page'] ?? '') ?? 999999;
      final bPage = int.tryParse(bData['page'] ?? '') ?? 999999;
      if (aPage != bPage) return aPage.compareTo(bPage);
      // 同ページ内はsortOrderで順序を保持
      final aSort = (aData['sortOrder'] as num?)?.toInt() ?? 999999000;
      final bSort = (bData['sortOrder'] as num?)?.toInt() ?? 999999000;
      return aSort.compareTo(bSort);
    });
    return sorted;
  }

  Future<void> _deleteMemo(BuildContext context, String memoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除'),
        content: const Text('このメモを削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('books').doc(widget.book.id)
          .collection('memos').doc(memoId).delete();
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    // ローカルを即時更新（チラつきなし）
    setState(() {
      _isReordering = true;
      final item = _sortedMemos.removeAt(oldIndex);
      _sortedMemos.insert(newIndex, item);
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _isReordering = false); return; }

    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _sortedMemos.length; i++) {
      final ref = FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('books').doc(widget.book.id)
          .collection('memos').doc(_sortedMemos[i].id);
      batch.update(ref, {'sortOrder': i * 1000});
    }
    await batch.commit();
    if (mounted) setState(() => _isReordering = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('books').doc(widget.book.id)
          .collection('memos')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        // Firestoreの更新を受けたときだけローカルリストを更新
        if (!_isReordering) {
          _sortedMemos = _sortMemos(snapshot.data!.docs);
        }

        if (_sortedMemos.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📝 読書メモ',
                  style: TextStyle(fontSize: kIsWeb ? 14 : 12, fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
                const SizedBox(width: 8),
                Text('長押しで並び替え',
                  style: TextStyle(fontSize: kIsWeb ? 11 : 9,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 10),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _handleReorder,
              itemCount: _sortedMemos.length,
              itemBuilder: (context, index) {
                final doc = _sortedMemos[index];
                final data = doc.data() as Map<String, dynamic>;
                final content = data['content'] as String? ?? '';
                final type = data['type'] as String? ?? '';
                final page = data['page'] as String? ?? '';
                final importance = data['importance'] as String? ?? '';
                // カード全体を長押しでドラッグ開始
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(doc.id),
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ドラッグヒント帯（カード上部）
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.border.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10)),
                          ),
                          child: Icon(Icons.drag_handle,
                            size: 16,
                            color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (type.isNotEmpty || page.isNotEmpty || importance.isNotEmpty) ...[
                                Wrap(
                                  spacing: 6, runSpacing: 4,
                                  children: [
                                    if (type.isNotEmpty) _MemoTag(label: type),
                                    if (page.isNotEmpty) _MemoTag(label: 'p.$page'),
                                    if (importance.isNotEmpty) _MemoTag(label: importance),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(content,
                                textAlign: TextAlign.justify,
                                style: const TextStyle(
                                  fontSize: kIsWeb ? 14 : 12, color: AppTheme.textPrimary, height: 1.6)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // コピーボタン
                                  TextButton(
                                    onPressed: () async {
                                      final content = data['content'] as String? ?? '';
                                      await Clipboard.setData(ClipboardData(text: content));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('メモをコピーしました'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('📋 コピー',
                                      style: TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.textSecondary)),
                                  ),
                                  TextButton(
                                    onPressed: () => pushResponsive(context, MemoFormScreen(
                                          books: [widget.book],
                                          initialBookId: widget.book.id,
                                          memoId: doc.id,
                                          existingMemo: data,
                                        )),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('✏ 編集',
                                      style: TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.gold)),
                                  ),
                                  TextButton(
                                    onPressed: () => _deleteMemo(context, doc.id),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('🗑 削除',
                                      style: TextStyle(fontSize: kIsWeb ? 12 : 10, color: Colors.red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _MemoTag extends StatelessWidget {
  final String label;
  const _MemoTag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.tagBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: kIsWeb ? 11 : 9, color: AppTheme.textSecondary)));
}
