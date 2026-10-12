import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_theme.dart';
import '../../utils/responsive_nav.dart';
import '../../utils/cover_image.dart';
import '../book_detail_screen.dart';
import '../settings_screen.dart';

/// 本棚タブの中身（本の一覧だけ）。
/// ヘッダーと「本棚／読み中／読みたい…」の並びは外枠（MobileShell）が
/// 全画面共通で出しているので、ここには持たない。
/// 状態の絞り込み・検索の開閉・表示切替は外枠から操作されるため、状態を外枠と共有する。
class MobileBookshelfPage extends StatefulWidget {
  final ValueNotifier<String> filter;     // all / reading / wish / stack / done
  final ValueNotifier<bool> searchOpen;   // 検索欄を開いているか
  final ValueNotifier<String> viewMode;   // grid=表紙グリッド list=リスト
  const MobileBookshelfPage({
    super.key,
    required this.filter,
    required this.searchOpen,
    required this.viewMode,
  });

  @override
  State<MobileBookshelfPage> createState() => MobileBookshelfPageState();
}

class MobileBookshelfPageState extends State<MobileBookshelfPage> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();

  String _sort = 'newest';
  String _searchQuery = '';
  bool _sheetOpen = false;

  String get _filter => widget.filter.value;
  bool get _searchOpen => widget.searchOpen.value;
  String get _viewMode => widget.viewMode.value;

  @override
  void initState() {
    super.initState();
    widget.filter.addListener(_rebuild);
    widget.searchOpen.addListener(_onSearchOpenChanged);
    widget.viewMode.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.filter.removeListener(_rebuild);
    widget.searchOpen.removeListener(_onSearchOpenChanged);
    widget.viewMode.removeListener(_rebuild);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchOpenChanged() {
    if (!mounted) return;
    setState(() {
      // 検索欄を閉じたら、検索の文字も消す
      if (!_searchOpen) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// 下から出すシート。枠の中に開く。
  /// すでにシートが開いているときは、それを閉じるだけにする。
  Future<void> _openSheet(WidgetBuilder builder) async {
    final nav = Navigator.of(context);
    nav.popUntil((route) => route is PageRoute);
    if (_sheetOpen) return;
    _sheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MobileTheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: builder,
    );
    _sheetOpen = false;
  }

  List<Book> _applyFilterSort(List<Book> books) {
    var list = books.where((b) {
      if (_filter != 'all' && b.status != _filter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q) ||
            b.tags.any((t) => t.toLowerCase().contains(q));
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'newest': list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); break;
      case 'oldest': list.sort((a, b) => a.createdAt.compareTo(b.createdAt)); break;
      case 'title':  list.sort((a, b) => a.title.compareTo(b.title)); break;
      case 'author': list.sort((a, b) => a.author.compareTo(b.author)); break;
      case 'status':
        const o = {'reading': 0, 'wish': 1, 'stack': 2, 'done': 3};
        list.sort((a, b) => (o[a.status] ?? 9).compareTo(o[b.status] ?? 9));
        break;
      case 'progress':
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      default:
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return list;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading': return '📖 読み中';
      case 'wish':    return '🌙 読みたい';
      case 'stack':   return '📚 積読';
      case 'done':    return '✅ 読了';
      default:        return '';
    }
  }

  void showSortSheet() {
    const sorts = [
      {'val': 'manual',   'label': '手動順'},
      {'val': 'newest',   'label': '登録新しい順'},
      {'val': 'oldest',   'label': '登録古い順'},
      {'val': 'title',    'label': 'タイトル順'},
      {'val': 'author',   'label': '著者順'},
      {'val': 'status',   'label': '状態別'},
      {'val': 'progress', 'label': '進捗順'},
    ];
    _openSheet(
      (_) => ListView(
        shrinkWrap: true,
        children: sorts.map((s) => ListTile(
          title: Text(s['label']!, style: MobileTheme.body(fontSize: 15, fontWeight: FontWeight.w600)),
          trailing: _sort == s['val']
              ? const Icon(Icons.radio_button_checked, color: MobileTheme.goldLine)
              : const Icon(Icons.radio_button_unchecked, color: MobileTheme.cardBorder),
          onTap: () {
            setState(() => _sort = s['val']!);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  void showMoreSheet() {
    _openSheet(
      (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.touch_app_rounded, color: MobileTheme.textSub),
              title: Text('手動順のときは長押しで並び替え',
                style: MobileTheme.body(fontSize: 13, color: MobileTheme.textSub)),
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded, color: MobileTheme.textSub),
              title: Text('設定を開く', style: MobileTheme.body(fontSize: 15, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                pushResponsive(context, const SettingsScreen());
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.bg,
      child: StreamBuilder<List<Book>>(
        stream: _firestoreService.booksStream(),
        builder: (context, snapshot) {
          final allBooks = snapshot.data ?? [];
          final displayed = _applyFilterSort(allBooks);
          return Column(
            children: [
              if (_searchOpen) _buildSearchBar(),
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                        child: Text('本がまだありません',
                          style: MobileTheme.body(fontSize: 13, color: MobileTheme.textSub)),
                      )
                    : (_viewMode == 'grid' ? _buildGrid(displayed) : _buildList(displayed)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: MobileTheme.bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: MobileTheme.body(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'タイトル・著者・タグで検索',
          hintStyle: MobileTheme.body(fontSize: 13, color: MobileTheme.textSub),
          filled: true,
          fillColor: MobileTheme.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: MobileTheme.cardBorder)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: MobileTheme.cardBorder)),
        ),
      ),
    );
  }

  Widget _buildGrid(List<Book> books) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.58,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) {
        final book = books[i];
        return GestureDetector(
          onTap: () => pushResponsive(context, BookDetailScreen(book: book)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4, offset: const Offset(1, 2))],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: book.thumbnail != null
                          ? CoverNetworkImage(url: book.thumbnail!, fit: BoxFit.cover,
                              placeholderBuilder: (_) => _coverPlaceholder())
                          : _coverPlaceholder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: MobileTheme.body(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_statusLabel(book.status),
                style: MobileTheme.body(fontSize: 10, color: MobileTheme.textSub)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<Book> books) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: books.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final book = books[i];
        return GestureDetector(
          onTap: () => pushResponsive(context, BookDetailScreen(book: book)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: MobileTheme.cardDecoration(radius: 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 40, height: 56,
                    child: book.thumbnail != null
                        ? CoverNetworkImage(url: book.thumbnail!, fit: BoxFit.cover,
                            placeholderBuilder: (_) => _coverPlaceholder())
                        : _coverPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: MobileTheme.body(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_statusLabel(book.status),
                        style: MobileTheme.body(fontSize: 11, color: MobileTheme.textSub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder() => Container(
    color: MobileTheme.cardBorder,
    child: const Center(child: Text('📖', style: TextStyle(fontSize: 18))));
}
