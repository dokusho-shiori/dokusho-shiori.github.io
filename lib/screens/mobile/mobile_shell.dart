import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
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
/// 上の固定ヘッダー＋下部ナビゲーションを1つだけ持ち、
/// その間の枠の中で4つのタブ（ホーム／本棚／メモ／メニュー）や
/// 本の詳細・登録・メモ入力・登録シートなどをすべて開く。
/// 枠の中身用に専用のNavigatorを1つ持たせ、そこにpushするので、
/// どの画面を開いても上のヘッダーと下部ナビは動かない。
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final _innerNavigatorKey = GlobalKey<NavigatorState>();
  final _tabNotifier = ValueNotifier<MobileTab>(MobileTab.home);
  final _firestoreService = FirestoreService();

  // 本棚タブの検索・表示切替は、固定ヘッダーのアイコンから操作する
  final _bookshelfKey = GlobalKey<MobileBookshelfPageState>();
  final _searchOpen = ValueNotifier<bool>(false);
  final _viewMode = ValueNotifier<String>('grid');

  // 枠の中で開いている画面の数（1＝タブの画面だけ）
  final _pageDepth = ValueNotifier<int>(1);
  late final _depthObserver = _PageDepthObserver(_pageDepth);

  bool _registerSheetOpen = false;

  @override
  void dispose() {
    _tabNotifier.dispose();
    _searchOpen.dispose();
    _viewMode.dispose();
    _pageDepth.dispose();
    super.dispose();
  }

  void _goTo(MobileTab tab) {
    _innerNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    _tabNotifier.value = tab;
  }

  void _openBookshelfFiltered(String filter) {
    _innerNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    _bookshelfKey.currentState?.setFilter(filter);
    _tabNotifier.value = MobileTab.bookshelf;
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

  /// 固定ヘッダーの右側に出すアイコン。
  /// 本棚タブの一覧を表示しているときだけ、検索・並び替え・表示切替・その他を出す。
  List<Widget> _headerActions() {
    final onShelfList =
        _tabNotifier.value == MobileTab.bookshelf && _pageDepth.value <= 1;
    if (!onShelfList) return const [];
    return [
      _HeaderIcon(
        icon: _searchOpen.value ? Icons.close : Icons.search_rounded,
        onTap: () => _searchOpen.value = !_searchOpen.value,
      ),
      _HeaderIcon(
        icon: Icons.swap_vert_rounded,
        onTap: () => _bookshelfKey.currentState?.showSortSheet(),
      ),
      _HeaderIcon(
        icon: _viewMode.value == 'grid'
            ? Icons.view_list_rounded
            : Icons.grid_view_rounded,
        onTap: () =>
            _viewMode.value = _viewMode.value == 'grid' ? 'list' : 'grid',
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
      // 上の固定ヘッダー（どの画面を開いても同じものが出続ける）
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(_ShellHeader.height),
        child: AnimatedBuilder(
          animation: Listenable.merge(
              [_tabNotifier, _pageDepth, _searchOpen, _viewMode]),
          builder: (context, _) => _ShellHeader(actions: _headerActions()),
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
                  onOpenBookshelf: _openBookshelfFiltered,
                  onOpenBookDetail: _openBookDetail,
                ),
                MobileBookshelfPage(
                  key: _bookshelfKey,
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

/// 上の固定ヘッダー。左にロゴ、右にその画面用のアイコン（あれば）。
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
