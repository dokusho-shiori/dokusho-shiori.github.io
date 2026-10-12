import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/mobile_theme.dart';
import '../../widgets/mobile/mobile_bottom_nav.dart';
import '../../widgets/mobile/register_sheet.dart';
import '../book_detail_screen.dart';
import '../book_form_screen.dart';
import '../memo_form_screen.dart';
import '../settings_screen.dart';
import 'mobile_bookshelf_page.dart';
import 'mobile_home_page.dart';
import 'mobile_memo_page.dart';

/// 画面幅600px未満のときに表示するスマホ専用シェル（外枠）。
/// 上の固定部分（ロゴと検索などのアイコンのヘッダー＋「本棚／読み中／読みたい…」の並び）と
/// 下部ナビゲーションを1つだけ持ち、その間の枠の中で
/// 4つのタブ（ホーム／本棚／メモ／メニュー）や
/// 本の詳細・登録・メモ入力・登録シートなどをすべて開く。
/// 枠の中身用に専用のNavigatorを1つ持たせ、そこにpushするので、
/// どの画面を開いても上の固定部分と下部ナビは消えない・動かない。
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final _innerNavigatorKey = GlobalKey<NavigatorState>();
  final _tabNotifier = ValueNotifier<MobileTab>(MobileTab.home);
  final _firestoreService = FirestoreService();

  // 上の「本棚／読み中…」の件数に使う本の一覧
  late final Stream<List<Book>> _booksStream = _firestoreService.booksStream();

  // 本棚の絞り込み・検索・表示切替は、上の固定部分から操作する
  final _bookshelfKey = GlobalKey<MobileBookshelfPageState>();
  final _filter = ValueNotifier<String>('all');
  final _searchOpen = ValueNotifier<bool>(false);
  final _viewMode = ValueNotifier<String>('grid');

  // 枠の中で開いている画面の数（1＝タブの画面だけ）
  final _pageDepth = ValueNotifier<int>(1);
  late final _depthObserver = _PageDepthObserver(_pageDepth);

  bool _registerSheetOpen = false;

  @override
  void dispose() {
    _tabNotifier.dispose();
    _filter.dispose();
    _searchOpen.dispose();
    _viewMode.dispose();
    _pageDepth.dispose();
    super.dispose();
  }

  void _goTo(MobileTab tab) {
    _innerNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    _tabNotifier.value = tab;
  }

  /// 本棚の一覧を出しているか（本の詳細などを上に開いていない状態）
  bool get _onShelfList =>
      _tabNotifier.value == MobileTab.bookshelf && _pageDepth.value <= 1;

  /// 開いている画面を閉じて、本棚の一覧を出す
  void _showShelfList() {
    _innerNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    _tabNotifier.value = MobileTab.bookshelf;
  }

  /// 「読み中だけ」などを指定して本棚の一覧を出す。
  /// 上の「本棚／読み中…」の並びや、ホームのタイルから呼ばれる。
  void _openBookshelfFiltered(String filter, {bool closeSearch = false}) {
    if (closeSearch) _searchOpen.value = false;
    _filter.value = filter;
    _showShelfList();
  }

  void _openBookDetail(Book book) {
    _innerNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)));
  }

  void _openBookForm() {
    _innerNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const BookFormScreen()));
  }

  Future<void> _openMemoForm({String? initialBookId}) async {
    final books = await _firestoreService.booksStream().first;
    if (!mounted) return;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に本を登録してください')));
      return;
    }
    _innerNavigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => MemoFormScreen(books: books, initialBookId: initialBookId)));
  }

  /// 登録シートも枠の中（ヘッダーと下部ナビの間）に開く。
  /// 開いている間にもう一度「登録」を押したら閉じる。
  Future<void> _onRegisterTap() async {
    final nav = _innerNavigatorKey.currentState;
    final overlayContext = nav?.overlay?.context;
    if (nav == null || overlayContext == null) return;
    // すでに何かのシートが開いていれば、先に閉じる
    nav.popUntil((route) => route is PageRoute);
    if (_registerSheetOpen) return;
    _registerSheetOpen = true;
    await showRegisterSheet(
      overlayContext,
      onRegisterBook: _openBookForm,
      onAddMemo: () => _openMemoForm(),
    );
    _registerSheetOpen = false;
  }

  /// 固定ヘッダーの右側のアイコン（検索・並び替え・表示切替・その他）。
  /// どの画面でも出したままにする。
  /// 本棚の一覧以外の画面で押したときは、本棚の一覧に移ってから動かす。
  List<Widget> _headerActions() {
    return [
      _HeaderIcon(
        icon: _onShelfList && _searchOpen.value
            ? Icons.close
            : Icons.search_rounded,
        onTap: () {
          if (_onShelfList) {
            _searchOpen.value = !_searchOpen.value;
          } else {
            _showShelfList();
            _searchOpen.value = true;
          }
        },
      ),
      _HeaderIcon(
        icon: Icons.swap_vert_rounded,
        onTap: () {
          if (!_onShelfList) _showShelfList();
          _bookshelfKey.currentState?.showSortSheet();
        },
      ),
      _HeaderIcon(
        icon: _viewMode.value == 'grid'
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded,
        onTap: () {
          if (!_onShelfList) _showShelfList();
          _viewMode.value = _viewMode.value == 'grid' ? 'list' : 'grid';
        },
      ),
      _HeaderIcon(
        icon: Icons.more_horiz_rounded,
        onTap: () => _bookshelfKey.currentState?.showMoreSheet(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.bg,
      // 上の固定部分（どの画面を開いても同じものが出続ける）
      //   1段目：ロゴ＋検索などのアイコン
      //   2段目：「本棚／読み中／読みたい／積読／読了」の並び
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(
            _ShellHeader.height + _StatusTabs.height),
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [_tabNotifier, _pageDepth, _filter, _searchOpen, _viewMode]),
          builder: (context, _) => Column(
            children: [
              _ShellHeader(actions: _headerActions()),
              StreamBuilder<List<Book>>(
                stream: _booksStream,
                builder: (context, snapshot) => _StatusTabs(
                  books: snapshot.data ?? const [],
                  // 本棚タブを出しているときだけ、選んでいる状態に色を付ける
                  activeKey: _tabNotifier.value == MobileTab.bookshelf
                      ? _filter.value
                      : null,
                  onSelect: _openBookshelfFiltered,
                ),
              ),
            ],
          ),
        ),
      ),
      // 枠の中身。ここだけが切り替わる
      body: Navigator(
        key: _innerNavigatorKey,
        observers: [_depthObserver],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => ValueListenableBuilder<MobileTab>(
            valueListenable: _tabNotifier,
            builder: (context, tab, _) => IndexedStack(
              index: tab.index,
              children: [
                MobileHomePage(
                  onOpenBookshelf: (filter) =>
                      _openBookshelfFiltered(filter, closeSearch: true),
                  onOpenBookDetail: _openBookDetail,
                ),
                MobileBookshelfPage(
                  key: _bookshelfKey,
                  filter: _filter,
                  searchOpen: _searchOpen,
                  viewMode: _viewMode,
                ),
                const MobileMemoPage(),
                const _MenuPage(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<MobileTab>(
        valueListenable: _tabNotifier,
        builder: (context, tab, _) => MobileBottomNav(
          current: tab,
          onSelect: _goTo,
          onRegister: _onRegisterTap,
        ),
      ),
    );
  }
}

/// 上の固定ヘッダー（1段目）。左にロゴ、右に検索などのアイコン。
class _ShellHeader extends StatelessWidget {
  static const double height = 56;
  final List<Widget> actions;
  const _ShellHeader({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.dark,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/shiori_logo.png',
                    width: 32, height: 32, fit: BoxFit.cover,
                  ),
                ),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 上の固定部分の2段目。「本棚／読み中／読みたい／積読／読了」の並び。
/// PC版の本棚タブと同じ項目・順番・配色（設定タブは含めない）。
/// どの画面でも出したままにし、押すとその状態で絞り込んだ本棚の一覧を出す。
class _StatusTabs extends StatelessWidget {
  static const double height = 52;
  final List<Book> books;
  final String? activeKey;
  final void Function(String key) onSelect;
  const _StatusTabs({
    required this.books,
    required this.activeKey,
    required this.onSelect,
  });

  int _count(String status) => books.where((b) => b.status == status).length;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      {'key': 'all',     'label': '📚 本棚',    'count': '${books.length}'},
      {'key': 'reading', 'label': '📖 読み中',  'count': '${_count('reading')}'},
      {'key': 'wish',    'label': '🌙 読みたい', 'count': '${_count('wish')}'},
      {'key': 'stack',   'label': '📚 積読',    'count': '${_count('stack')}'},
      {'key': 'done',    'label': '✅ 読了',    'count': '${_count('done')}'},
    ];

    return Container(
      color: AppTheme.tabBg,
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final isActive = activeKey == tab['key'];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(tab['key']!),
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
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? AppTheme.gold : const Color(0xFFAAAAAA))),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.gold : const Color(0xFF555555),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(tab['count']!,
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: isActive ? Colors.black : Colors.white)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44, height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: MobileTheme.goldOnDark, size: 22),
        ),
      ),
    );
  }
}

/// 枠の中で開いている画面（ページ）の数を数える。
/// シートやポップアップは数えない。
class _PageDepthObserver extends NavigatorObserver {
  final ValueNotifier<int> depth;
  int _count = 0;
  _PageDepthObserver(this.depth);

  void _change(Route<dynamic>? route, int delta) {
    if (route is! PageRoute) return;
    _count += delta;
    // 画面の組み立て中に通知すると不具合になるので、その場合は描画後に反映する
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance
          .addPostFrameCallback((_) => depth.value = _count);
    } else {
      depth.value = _count;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _change(route, -1);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _change(oldRoute, -1);
    _change(newRoute, 1);
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('メニュー', style: MobileTheme.heading(fontSize: 20)),
          ),
          const Expanded(child: SettingsScreen(embedded: true)),
        ],
      ),
    );
  }
}
