import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';
import '../screens/memo_form_screen.dart';
import '../screens/book_detail_screen.dart';
import '../utils/responsive_nav.dart';
import '../utils/cover_image.dart';
import '../utils/link_utils.dart';
import '../utils/url_utils.dart';
import '../services/firestore_service.dart';
import 'link_dialog.dart';

class BookCard extends StatefulWidget {
  final Book book;
  final List<Book> allBooks;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onAddMemo;
  final VoidCallback? onDetail;

  const BookCard({
    super.key,
    required this.book,
    required this.allBooks,
    required this.onTap,
    required this.onDelete,
    this.onAddMemo,
    this.onDetail,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _memoOpen = false;

  // この本のメモ。件数ボタンとメモ一覧で同じ読み取りを共有する
  Stream<QuerySnapshot>? _memoStream;

  @override
  void initState() {
    super.initState();
    _memoStream = _createMemoStream();
  }

  @override
  void didUpdateWidget(BookCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.id != widget.book.id) {
      _memoStream = _createMemoStream();
    }
  }

  Stream<QuerySnapshot>? _createMemoStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('books').doc(widget.book.id)
        .collection('memos')
        .orderBy('createdAt')
        .snapshots();
  }

  // 本の詳細を開いて、メモ一覧の位置まで移動する
  void _openMemos() {
    pushResponsive(context,
        BookDetailScreen(book: widget.book, scrollToMemos: true));
  }

  // リンク登録済みなら開く。未登録ならURLを入力して保存する
  Future<void> _onLinkTap() async {
    final current = normalizeLinkUrl(widget.book.linkUrl);
    if (current != null) {
      openExternalUrl(current);
      return;
    }
    final url = await showLinkInputDialog(context);
    if (url == null) return;
    try {
      await FirestoreService().updateBookLink(widget.book.id, url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リンクの保存に失敗しました: $e')));
    }
  }

  Color get _barColor {
    switch (widget.book.status) {
      case 'reading': return AppTheme.readingBar;
      case 'wish':    return AppTheme.wishBar;
      case 'stack':   return AppTheme.stackBar;
      case 'done':    return AppTheme.doneBar;
      default:        return AppTheme.doneBar;
    }
  }

  String get _statusLabel {
    switch (widget.book.status) {
      case 'reading': return '📖 読み中';
      case 'wish':    return '🌙 読みたい';
      case 'stack':   return '📚 積読';
      case 'done':    return '✅ 読了';
      default:        return '';
    }
  }

  void _openEditMemo(String memoId, Map<String, dynamic> memoData) {
    pushResponsive(context, MemoFormScreen(
      books: widget.allBooks,
      initialBookId: widget.book.id,
      memoId: memoId,
      existingMemo: memoData,
    ));
  }

  Future<void> _deleteMemo(String memoId) async {
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

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      // メモの読み取りは1本だけ。ボタンの件数表示とメモ一覧の両方で使う
      child: StreamBuilder<QuerySnapshot>(
        stream: _memoStream,
        builder: (context, snapshot) {
          final memos = snapshot.data?.docs ?? const <QueryDocumentSnapshot>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => pushResponsive(context, BookDetailScreen(book: widget.book)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5, height: 110,
                        decoration: BoxDecoration(
                          color: _barColor,
                          borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.title,
                              style: const TextStyle(
                                fontSize: kIsWeb ? 16 : 14, fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary, height: 1.4)),
                            const SizedBox(height: 4),
                            Text(
                              [book.author, book.publisher]
                                  .where((s) => s.isNotEmpty).join(' / '),
                              style: const TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6, runSpacing: 4,
                              children: [
                                _Tag(label: _statusLabel),
                                ...book.tags.map((t) => _Tag(label: t)),
                              ],
                            ),
                            if (book.memo != null && book.memo!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(book.memo!,
                                style: const TextStyle(
                                  fontSize: kIsWeb ? 12 : 10, color: AppTheme.textSecondary, height: 1.5),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 10),
                            // 表紙とアクションボタンを横並びにする。
                            // 表紙の上端を「本の詳細」ボタンの上端にそろえる
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CoverImage(book: book),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _CardActions(
                                    onDetail: widget.onDetail ?? () => pushResponsive(context, BookDetailScreen(book: widget.book)),
                                    onEdit: widget.onTap,
                                    onDelete: widget.onDelete,
                                    onAddMemo: widget.onAddMemo,
                                    memoCount: memos.length,
                                    onViewMemos: _openMemos,
                                    linkUrl: normalizeLinkUrl(book.linkUrl),
                                    onLink: _onLinkTap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (book.status == 'reading' && book.totalPages > 0)
                _ProgressBar(book: book),
              // メモ一覧（Firestoreからリアルタイム）
              _MemoSection(
                memos: memos,
                isOpen: _memoOpen,
                onToggle: () => setState(() => _memoOpen = !_memoOpen),
                onEdit: _openEditMemo,
                onDelete: _deleteMemo,
              ),
            ],
          );
        },
      ),
    );
  }
}

// メモセクション（表示/非表示切替付き）
class _MemoSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> memos;
  final bool isOpen;
  final VoidCallback onToggle;
  final Function(String, Map<String, dynamic>) onEdit;
  final Function(String) onDelete;

  const _MemoSection({
    required this.memos,
    required this.isOpen,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (memos.isEmpty) return const SizedBox();

    return Column(
      children: [
        Container(height: 1, color: AppTheme.border),
        // メモヘッダー（件数・表示切替ボタン）
        GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Text('📝 メモ一覧（${memos.length}件）',
                  style: const TextStyle(
                    fontSize: kIsWeb ? 13 : 11, fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
                const Spacer(),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        // メモリスト
        if (isOpen) ...[
          ...memos.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final content = data['content'] as String? ?? '';
            final type = data['type'] as String? ?? '';
            final page = data['page'] as String? ?? '';
            final importance = data['importance'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type.isNotEmpty || page.isNotEmpty || importance.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        children: [
                          if (type.isNotEmpty) _MemoChip(label: type),
                          if (page.isNotEmpty) _MemoChip(label: 'p.$page'),
                          if (importance.isNotEmpty) _MemoChip(label: importance),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(content,
                      style: const TextStyle(
                        fontSize: kIsWeb ? 13 : 11, color: AppTheme.textPrimary, height: 1.5)),
                    const SizedBox(height: 8),
                    // 編集・削除ボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onEdit(doc.id, data),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text('✏ 編集',
                                style: TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.gold)),
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => onDelete(doc.id),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Text('🗑 削除',
                                style: TextStyle(fontSize: kIsWeb ? 12 : 10, color: Colors.red)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _MemoChip extends StatelessWidget {
  final String label;
  const _MemoChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.tagBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(label,
      style: const TextStyle(fontSize: kIsWeb ? 11 : 9, color: AppTheme.textSecondary)),
  );
}

class _CoverImage extends StatelessWidget {
  final Book book;
  const _CoverImage({required this.book});

  @override
  Widget build(BuildContext context) {
    final url = book.thumbnail;
    return Column(
      children: [
        Container(
          width: 60, height: 85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6, offset: const Offset(2, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: url != null
                ? CoverNetworkImage(url: url, fit: BoxFit.cover,
                    placeholderBuilder: (_) => _Placeholder())
                : _Placeholder(),
          ),
        ),
        const SizedBox(height: 4),
        const Text('タップで詳細',
          style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFD4C9B0),
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 24))));
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.tagBg,
      border: Border.all(color: const Color(0xFFC9B890)),
      borderRadius: BorderRadius.circular(14)),
    child: Text(label, style: const TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.textPrimary)),
  );
}

class _ProgressBar extends StatelessWidget {
  final Book book;
  const _ProgressBar({required this.book});

  @override
  Widget build(BuildContext context) {
    final pct = (book.progress * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('読書進捗',
                style: TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.textSecondary)),
              Text('p.${book.currentPage} / ${book.totalPages}（$pct%）',
                style: const TextStyle(fontSize: kIsWeb ? 12 : 10, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: book.progress,
              backgroundColor: const Color(0xFFD4C9B0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.progressFill),
              minHeight: 7),
          ),
        ],
      ),
    );
  }
}

class _CardActions extends StatelessWidget {
  final VoidCallback? onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAddMemo;
  final int memoCount;
  final VoidCallback onViewMemos;
  /// 登録済みの関連リンク（未登録なら null）
  final String? linkUrl;
  final VoidCallback onLink;
  const _CardActions({
    this.onDetail,
    required this.onEdit,
    required this.onDelete,
    this.onAddMemo,
    required this.memoCount,
    required this.onViewMemos,
    required this.linkUrl,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _ActionBtn(label: '本の詳細', onTap: onDetail),
        _ActionBtn(label: '本の編集', onTap: onEdit),
        _ActionBtn(label: '本の削除', onTap: onDelete),
        _ActionBtn(label: 'メモの追加', onTap: onAddMemo, enabled: onAddMemo != null),
        // メモがある本だけ「メモを見る（件数）」を出す
        if (memoCount > 0)
          _ActionBtn(label: 'メモを見る（$memoCount）', onTap: onViewMemos),
        _ActionBtn(
          label: linkUrl != null ? linkOpenLabel(linkUrl!) : 'リンク追加',
          onTap: onLink),
      ],
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  const _ActionBtn({required this.label, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? AppTheme.border : AppTheme.border.withValues(alpha: 0.4),
            width: 1.5),
          borderRadius: BorderRadius.circular(8)),
        child: Text(label,
          style: TextStyle(
            fontSize: kIsWeb ? 11 : 9,
            color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary)),
      ),
    ),
  );
}

// コンパクト表示用カード（サムネイル・タイトルのみ）
class BookCardCompact extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCardCompact({
    super.key,
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: SizedBox.expand(
                  child: book.thumbnail != null
                      ? CoverNetworkImage(url: book.thumbnail!, fit: BoxFit.contain,
                          placeholderBuilder: (_) => _CompactPlaceholder())
                      : _CompactPlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(book.title,
                style: const TextStyle(
                  fontSize: kIsWeb ? 11 : 9, fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFD4C9B0),
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 32))));
}
