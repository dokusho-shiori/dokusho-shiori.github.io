import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/firestore_service.dart';
import '../../theme/mobile_theme.dart';
import '../../utils/responsive_nav.dart';
import '../../widgets/mobile/mobile_bottom_nav.dart';
import '../../widgets/mobile/register_sheet.dart';
import '../book_detail_screen.dart';
import '../book_form_screen.dart';
import '../memo_form_screen.dart';
import '../settings_screen.dart';
import 'mobile_bookshelf_page.dart';
import 'mobile_home_page.dart';
import 'mobile_memo_page.dart';

/// 画面幅600px未満のときに表示するスマホ専用シェル。
/// 下部ナビゲーション＋4つのタブ（ホーム／本棚／メモ／メニュー）＋登録シートを束ねる。
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  MobileTab _tab = MobileTab.home;
  final _firestoreService = FirestoreService();
  String _bookshelfFilter = 'all';
  int _bookshelfRequestId = 0;

  void _goTo(MobileTab tab) => setState(() => _tab = tab);

  void _openBookshelfFiltered(String filter) {
    setState(() {
      _bookshelfFilter = filter;
      _bookshelfRequestId++;
      _tab = MobileTab.bookshelf;
    });
  }

  void _openBookDetail(Book book) => pushResponsive(context, BookDetailScreen(book: book));

  void _openBookForm() => pushResponsive(context, const BookFormScreen());

  Future<void> _openMemoForm({String? initialBookId}) async {
    final books = await _firestoreService.booksStream().first;
    if (!mounted) return;
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に本を登録してください')));
      return;
    }
    pushResponsive(context, MemoFormScreen(books: books, initialBookId: initialBookId));
  }

  void _onRegisterTap() {
    showRegisterSheet(
      context,
      onRegisterBook: _openBookForm,
      onAddMemo: () => _openMemoForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: IndexedStack(
          index: _tab.index,
          children: [
            MobileHomePage(
              onOpenBookshelf: _openBookshelfFiltered,
              onOpenBookDetail: _openBookDetail,
            ),
            MobileBookshelfPage(
              key: ValueKey(_bookshelfRequestId),
              initialFilter: _bookshelfFilter,
            ),
            const MobileMemoPage(),
            const _MenuPage(),
          ],
        ),
      ),
      bottomNavigationBar: MobileBottomNav(
        current: _tab,
        onSelect: _goTo,
        onRegister: _onRegisterTap,
      ),
    );
  }
}

class _MenuPage extends StatelessWidget {
  const _MenuPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: MobileTheme.bg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 56,
              color: MobileTheme.dark,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('メニュー',
                style: MobileTheme.heading(fontSize: 16, color: Colors.white)),
            ),
            const Expanded(child: SettingsScreen(embedded: true)),
          ],
        ),
      ),
    );
  }
}
