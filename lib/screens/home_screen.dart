import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/book.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_nav.dart';
import '../widgets/book_card.dart';
import 'book_form_screen.dart';
import 'settings_screen.dart';
import 'memo_form_screen.dart';
import 'book_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String _filter = 'all';
  String _sort = 'newest';
  bool _searchOpen = false;
  bool _fabOpen = false;
  // 表示モード 'list'=通常リスト 'compact'=コンパクトグリッド
  String _viewMode = 'list';
  String _searchQuery = '';
  final _searchController = TextEditingController();

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

  int _countStatus(List<Book> books, String status) =>
      books.where((b) => b.status == status).length;

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Book>>(
        stream: _firestoreService.booksStream(),
        builder: (context, snapshot) {
          final allBooks = snapshot.data ?? [];
          final displayed = _applyFilterSort(allBooks);
          return Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  _buildNavTabs(allBooks),
                  Expanded(child: _buildBody(allBooks, displayed)),
                ],
              ),
              if (_fabOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _fabOpen = false),
                    child: Container(color: Colors.transparent),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.headerBg,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20, right: 20, bottom: 12,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
            final Uri url = Uri.parse('https://shiori-official.digitalhack-note.com/');
            if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
      },
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('栞', style: TextStyle(
                  fontSize: 28, color: AppTheme.gold,
                  fontWeight: FontWeight.w900, fontFamily: 'serif')),
                Text('SHIORI', style: TextStyle(
                  fontSize: 10, color: Color(0xFF888888), letterSpacing: 3)),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _authService.signOut(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF555555)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('ログアウト',
                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTabs(List<Book> books) {
    final tabs = [
      {'key': 'all',      'label': '📚 本棚',    'count': '${books.length}'},
      {'key': 'reading',  'label': '📖 読み中',   'count': '${_countStatus(books, 'reading')}'},
      {'key': 'wish',     'label': '🌙 読みたい', 'count': '${_countStatus(books, 'wish')}'},
      {'key': 'stack',    'label': '📚 積読',     'count': '${_countStatus(books, 'stack')}'},
      {'key': 'done',     'label': '✅ 読了',     'count': '${_countStatus(books, 'done')}'},
      {'key': 'settings', 'label': '⚙ 設定',     'count': ''},
    ];

    return Container(
      color: AppTheme.tabBg,
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isActive = _filter == tab['key'];
          return GestureDetector(
            onTap: () {
              setState(() => _filter = tab['key']!);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? AppTheme.gold : Colors.transparent,
                    width: 2.5)),
              ),
              child: Row(
                children: [
                  Text(tab['label']!,
                    style: TextStyle(
                      fontSize: kIsWeb ? 15 : 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? AppTheme.gold : const Color(0xFFAAAAAA))),
                  if (tab['count']!.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isActive ? AppTheme.gold : const Color(0xFF555555),
                        borderRadius: BorderRadius.circular(10)),
                      child: Text(tab['count']!,
                        style: TextStyle(
                          fontSize: kIsWeb ? 11 : 9, fontWeight: FontWeight.bold,
                          color: isActive ? Colors.black : Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<Book> allBooks, List<Book> displayed) {
    if (_filter == 'settings') {
      return const SettingsScreen(embedded: true);
    }
    return Column(
      children: [
        // アクションボタン（並び順ドロップダウン含む）
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              // スクロール可能なボタンエリア
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TopBtn(label: '📚 本を登録', color: AppTheme.btnRegister,
                        onTap: () => _openBookForm(null)),
                      const SizedBox(width: 8),
                      _TopBtn(label: '📝 メモ追加', color: AppTheme.btnMemo,
                        onTap: () => _openMemoForm(allBooks)),
                      const SizedBox(width: 8),
                      _TopBtn(label: '🔍 検索', color: AppTheme.btnSearch,
                        onTap: _toggleSearch),
                      const SizedBox(width: 8),
                      // 並び順ドロップダウン
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                          color: AppTheme.cardBg),
                        child: DropdownButton<String>(
                          value: _sort,
                          underline: const SizedBox(),
                          isDense: true,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          icon: const Icon(Icons.keyboard_arrow_down,
                            size: 15, color: AppTheme.textSecondary),
                          items: const [
                            DropdownMenuItem(value: 'manual',   child: Text('手動順')),
                            DropdownMenuItem(value: 'newest',   child: Text('登録新しい順')),
                            DropdownMenuItem(value: 'oldest',   child: Text('登録古い順')),
                            DropdownMenuItem(value: 'title',    child: Text('タイトル順')),
                            DropdownMenuItem(value: 'author',   child: Text('著者順')),
                            DropdownMenuItem(value: 'status',   child: Text('状態別')),
                            DropdownMenuItem(value: 'progress', child: Text('進捗順')),
                          ],
                          onChanged: (v) => setState(() => _sort = v ?? 'manual'),
                        ),
                      ),
                      if (_sort == 'manual' && _viewMode == 'list')
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text('本を長押しして並び替えできます',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 表示モードボタン（右端固定）
              GestureDetector(
                onTap: () => setState(() =>
                  _viewMode = _viewMode == 'list' ? 'compact' : 'list'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _viewMode == 'list' ? Icons.grid_view : Icons.view_list,
                    size: 20, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
        // 検索バー
        if (_searchOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: '🔍 タイトル・著者・タグで検索...',
                hintStyle: TextStyle(fontSize: kIsWeb ? 14 : 12, color: AppTheme.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _toggleSearch,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // 本リスト
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.gold,
            onRefresh: () async => setState(() {}),
            child: displayed.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 100),
                    Center(child: Column(children: [
                      Text('📚', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('本がまだありません。\n「本を登録」から追加してみましょう！',
                        textAlign: TextAlign.left,
                        style: TextStyle(fontSize: kIsWeb ? 14 : 12,
                          color: AppTheme.textSecondary, height: 1.8)),
                    ])),
                  ])
                : _viewMode == 'compact'
                    // コンパクトグリッド表示
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth > 600 ? 6 : 3;
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: displayed.length,
                            itemBuilder: (_, i) {
                              final book = displayed[i];
                              return BookCardCompact(
                                book: book,
                                onTap: () => pushResponsive(context, BookDetailScreen(book: book)),
                              );
                            },
                          );
                        },
                      )
                    // 通常リスト表示（カード長押しでドラッグ&ドロップ）
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                        itemCount: displayed.length,
                        onReorder: (oldIndex, newIndex) async {
                          if (_sort != 'manual') return;
                          if (newIndex > oldIndex) newIndex--;
                          final newList = [...displayed];
                          final item = newList.removeAt(oldIndex);
                          newList.insert(newIndex, item);
                          await _firestoreService.updateSortOrders(newList);
                        },
                        itemBuilder: (_, i) {
                          final book = displayed[i];
                          return ReorderableDelayedDragStartListener(
                            key: ValueKey(book.id),
                            index: i,
                            child: BookCard(
                              book: book,
                              allBooks: allBooks,
                              onDetail: () => pushResponsive(context, BookDetailScreen(book: book)),
                              onTap: () => _openBookForm(book),
                              onDelete: () => _deleteBook(book.id),
                              onAddMemo: () async {
                                final books = await _firestoreService.booksStream().first;
                                if (mounted) _openMemoForm(books, bookId: book.id);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  String get _sortLabel {
    const labels = {
      'manual': '手動順', 'newest': '登録新しい順', 'oldest': '登録古い順',
      'title': 'タイトル順', 'author': '著者順', 'status': '状態別', 'progress': '進捗順',
    };
    return labels[_sort] ?? '手動順';
  }

  void _showSortModal() {
    final sorts = [
      {'val': 'manual',   'label': '手動順'},
      {'val': 'newest',   'label': '登録新しい順'},
      {'val': 'oldest',   'label': '登録古い順'},
      {'val': 'title',    'label': 'タイトル順'},
      {'val': 'author',   'label': '著者順'},
      {'val': 'status',   'label': '状態別'},
      {'val': 'progress', 'label': '進捗順'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ListView(
        shrinkWrap: true,
        children: sorts.map((s) => ListTile(
          title: Text(s['label']!,
            style: TextStyle(fontSize: kIsWeb ? 16 : 14, fontWeight: FontWeight.w600)),
          trailing: _sort == s['val']
              ? const Icon(Icons.radio_button_checked, color: AppTheme.progressFill)
              : const Icon(Icons.radio_button_unchecked, color: AppTheme.border),
          onTap: () {
            setState(() => _sort = s['val']!);
            Navigator.pop(context);
          },
        )).toList(),
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabOpen) ...[
          _FloatBtn(
            emoji: '📚', label: '本登録', color: AppTheme.btnRegister,
            onTap: () { setState(() => _fabOpen = false); _openBookForm(null); }),
          const SizedBox(height: 10),
          _FloatBtn(
            emoji: '📝', label: 'メモ追加', color: AppTheme.btnMemo,
            onTap: () async {
              setState(() => _fabOpen = false);
              final books = await _firestoreService.booksStream().first;
              if (mounted) _openMemoForm(books);
            }),
          const SizedBox(height: 10),
          _FloatBtn(
            emoji: '🔍', label: '検索', color: AppTheme.btnSearch,
            onTap: () { setState(() => _fabOpen = false); _toggleSearch(); }),
          const SizedBox(height: 10),
        ],
        FloatingActionButton(
          backgroundColor: _fabOpen ? const Color(0xFF555555) : AppTheme.btnRegister,
          onPressed: () => setState(() => _fabOpen = !_fabOpen),
          child: Icon(_fabOpen ? Icons.close : Icons.menu, color: Colors.white),
        ),
      ],
    );
  }

  void _openBookForm(Book? book) {
    pushResponsive(context, BookFormScreen(book: book));
  }

  void _openMemoForm(List<Book> books, {String? bookId}) {
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に本を登録してください')));
      return;
    }
    pushResponsive(context, MemoFormScreen(books: books, initialBookId: bookId));
  }

  Future<void> _deleteBook(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除'),
        content: const Text('この本を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) await _firestoreService.deleteBook(id);
  }
}

class _TopBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _TopBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(
        color: Colors.white, fontSize: kIsWeb ? 12 : 10, fontWeight: FontWeight.w600)),
    ),
  );
}

class _FloatBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FloatBtn({required this.emoji, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: color, shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          Text(label, style: const TextStyle(
            fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}
