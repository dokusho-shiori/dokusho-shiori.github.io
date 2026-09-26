import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/book.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_nav.dart';
import 'book_detail_screen.dart';
import 'settings_screen.dart';

class BookFormScreen extends StatefulWidget {
  final Book? book;
  const BookFormScreen({super.key, this.book});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _firestoreService = FirestoreService();
  final _isbnController = TextEditingController();
  final _asinController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _publisherController = TextEditingController();
  final _pagesController = TextEditingController();
  final _currentPageController = TextEditingController();
  final _priceController = TextEditingController();
  final _memoController = TextEditingController();
  final _tagController = TextEditingController();

  String _status = 'wish';
  String? _coverUrl;
  List<String> _tags = [];
  bool _asinOpen = false;
  bool _isFetching = false;
  bool _isSaving = false;
  String? _buyDate;
  String? _startDate;
  String? _endDate;
  String? _purchaseLocation;
  List<String> _purchaseLocations = [...FirestoreService.defaultPurchaseLocations];
  String? _categoryId;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    if (b != null) {
      _titleController.text = b.title;
      _authorController.text = b.author;
      _publisherController.text = b.publisher;
      _pagesController.text = b.totalPages > 0 ? '${b.totalPages}' : '';
      _currentPageController.text = b.currentPage > 0 ? '${b.currentPage}' : '';
      _priceController.text = b.price > 0 ? '${b.price}' : '';
      _memoController.text = b.memo ?? '';
      _isbnController.text = b.isbn ?? '';
      _asinController.text = b.asin ?? '';
      _status = b.status;
      _coverUrl = b.thumbnail;
      _tags = [...b.tags];
      _buyDate = b.buyDate;
      _startDate = b.startDate;
      _purchaseLocation = b.purchaseLocation;
      _categoryId = b.categoryId;
      _endDate = b.endDate;
    }
    _firestoreService.getPurchaseLocations().then((list) {
      if (mounted) setState(() => _purchaseLocations = list);
    });
    _firestoreService.categoriesStream().first.then((list) {
      if (mounted) setState(() => _categories = list);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _isbnController, _asinController, _titleController,
      _authorController, _publisherController, _pagesController,
      _currentPageController, _priceController, _memoController, _tagController
    ]) { c.dispose(); }
    super.dispose();
  }

  // ISBN-13 → ISBN-10
  String? _isbn13toIsbn10(String isbn13) {
    if (isbn13.length != 13 || !isbn13.startsWith('978')) return null;
    final core = isbn13.substring(3, 12);
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += (10 - i) * int.parse(core[i]);
    }
    final check = (11 - (sum % 11)) % 11;
    return core + (check == 10 ? 'X' : '$check');
  }

  // ISBN-10 → ISBN-13
  String? _isbn10toIsbn13(String s) {
    if (s.length != 10) return null;
    final core = '978${s.substring(0, 9)}';
    if (core.contains(RegExp(r'[^0-9]'))) return null;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(core[i]) * (i % 2 == 0 ? 1 : 3);
    }
    return core + '${(10 - (sum % 10)) % 10}';
  }

  // ISBN / ASIN 共通取得（どちらのフィールドからも同じ挙動）
  Future<void> _fetchBookInfo(String raw) async {
    final input = raw.trim().replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
    if (input.isEmpty) return _snack('ISBN / ASINを入力してください');

    String? asin;   // Amazonカバー用
    String? isbn13; // Google Books / OpenBD用

    if (RegExp(r'^\d{13}$').hasMatch(input)) {
      // ISBN-13
      isbn13 = input;
      asin = _isbn13toIsbn10(input);
    } else if (RegExp(r'^\d{9}[\dX]$').hasMatch(input)) {
      // ISBN-10
      asin = input;
      isbn13 = _isbn10toIsbn13(input);
    } else if (input.length == 10) {
      // ASIN（B01G6MF4J2 等）
      asin = input;
    } else {
      return _snack('ISBN（10/13桁）またはASIN（10桁）を入力してください');
    }

    // カバーを即時表示
    if (asin != null) {
      setState(() => _coverUrl =
          'https://images-na.ssl-images-amazon.com/images/P/$asin.01.MZZZZZZZ.jpg');
    }

    // 書籍ISBNでなければカバーのみ
    if (isbn13 == null) {
      return _snack('表紙を取得しました（書籍ISBNがないため書誌情報は手入力してください）');
    }

    setState(() => _isFetching = true);
    try {
      bool googleFound = false;

      // Google Books
      final res = await http.get(
        Uri.parse('https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn13&maxResults=1'),
        headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final items = (jsonDecode(res.body) as Map<String, dynamic>)['items'] as List?;
        if (items != null && items.isNotEmpty) {
          googleFound = true;
          final vi = (items[0] as Map<String, dynamic>)['volumeInfo'] as Map<String, dynamic>;
          final title = vi['title'] as String? ?? '';
          final authorsRaw = vi['authors'];
          final authors = authorsRaw is List ? authorsRaw.cast<String>().join('・') : '';
          final publisher = vi['publisher'] as String? ?? '';
          final pageCount = vi['pageCount'] as int? ?? 0;
          setState(() {
            if (title.isNotEmpty) _titleController.text = title;
            if (authors.isNotEmpty) _authorController.text = authors;
            if (publisher.isNotEmpty) _publisherController.text = publisher;
            if (pageCount > 0) _pagesController.text = '$pageCount';
          });
        }
      }

      // OpenBD（出版社・金額。Google Booksにない場合はタイトル等も）
      try {
        final r2 = await http.get(
          Uri.parse('https://api.openbd.jp/v1/get?isbn=$isbn13'))
            .timeout(const Duration(seconds: 10));
        if (r2.statusCode == 200) {
          final data = jsonDecode(r2.body) as List?;
          if (data != null && data.isNotEmpty && data[0] != null) {
            final entry = data[0] as Map<String, dynamic>;
            final summary = entry['summary'] as Map<String, dynamic>?;
            if (summary != null) {
              final title = summary['title'] as String? ?? '';
              final author = summary['author'] as String? ?? '';
              final publisher = summary['publisher'] as String? ?? '';
              String? price;
              try {
                final onix = entry['onix'] as Map<String, dynamic>?;
                final supply = onix?['ProductSupply'] as Map<String, dynamic>?;
                final detail = supply?['SupplyDetail'] as Map<String, dynamic>?;
                final prices = detail?['Price'] as List?;
                price = (prices?.firstOrNull as Map<String, dynamic>?)?['PriceAmount'] as String?;
              } catch (_) {}
              setState(() {
                if (!googleFound && title.isNotEmpty) _titleController.text = title;
                if (!googleFound && author.isNotEmpty) _authorController.text = author;
                if (publisher.isNotEmpty) _publisherController.text = publisher;
                if (price != null && price!.isNotEmpty) _priceController.text = price!;
              });
            }
          }
        }
      } catch (_) {}

      _snack('取得しました！');
    } catch (e) {
      _snackLong('取得に失敗しました: $e');
    }
    setState(() => _isFetching = false);
  }

  Future<void> _fetchISBN() => _fetchBookInfo(_isbnController.text);
  Future<void> _fetchASIN() => _fetchBookInfo(_asinController.text);

  void _addTag() {
    final val = _tagController.text.trim();
    if (val.isEmpty) return;
    if (!_tags.contains(val)) setState(() => _tags.add(val));
    _tagController.clear();
  }

  void _removeTag(int i) => setState(() => _tags.removeAt(i));

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return _snack('タイトルを入力してください');
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final book = Book(
        id: widget.book?.id ?? '',
        title: title,
        author: _authorController.text.trim(),
        publisher: _publisherController.text.trim(),
        thumbnail: _coverUrl,
        isbn: _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
        asin: _asinController.text.trim().isEmpty ? null : _asinController.text.trim(),
        status: _status,
        currentPage: int.tryParse(_currentPageController.text) ?? 0,
        totalPages: int.tryParse(_pagesController.text) ?? 0,
        price: int.tryParse(_priceController.text) ?? 0,
        tags: _tags,
        memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
        buyDate: _buyDate,
        startDate: _startDate,
        purchaseLocation: _purchaseLocation,
        categoryId: _categoryId,
        endDate: _endDate,
        sortOrder: widget.book?.sortOrder ?? 0,
        createdAt: widget.book?.createdAt ?? now,
        updatedAt: now,
      );
      if (widget.book == null) {
        final docId = await _firestoreService.addBook(book);
        if (mounted) {
          final newBook = book.copyWith(id: docId);
          Navigator.pop(context);
          if (context.mounted) {
            pushResponsive(context, BookDetailScreen(book: newBook));
          }
        }
      } else {
        await _firestoreService.updateBook(book);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _snack('保存に失敗しました: $e');
    }
    setState(() => _isSaving = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _snackLong(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.book != null;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBg,
        title: Text(isEdit ? '✏️ 本を編集' : '📚 本を登録',
          style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: [
          // 表紙プレビュー
          if (_coverUrl != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(_coverUrl!, height: 120,
                    key: ValueKey(_coverUrl),
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.book, size: 60, color: AppTheme.textSecondary)),
                ),
              ),
            ),

          // ISBN
          const _Note(text: '📖 ISBN-13　表紙・タイトル・著者・出版社を自動取得'),
          const SizedBox(height: 2),
          const _Note(text: '本の裏表紙バーコード下 or Amazonの商品ページ「登録情報」欄に記載の13桁'),
          const SizedBox(height: 2),
          const _Note(text: 'ハイフンあり・なし両方OK（例：978-4-16-711012-3）'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HintField(
                  controller: _isbnController,
                  hint: '例：978-4-16-711012-3',
                  inputType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 8),
              _FetchBtn(
                label: _isFetching ? '取得中...' : '取得',
                onTap: _isFetching ? null : _fetchISBN,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ASIN
          GestureDetector(
            onTap: () => setState(() => _asinOpen = !_asinOpen),
            child: Row(
              children: [
                Text(_asinOpen ? '▼' : '▶',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(width: 6),
                const Text('ISBNがない場合（ASIN）',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (_asinOpen) ...[
            const SizedBox(height: 6),
            const _Note(text: 'AmazonのURLの dp/ 以降の10桁・表紙のみ取得'),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _HintField(controller: _asinController,
                    hint: '例：B0CX1234AB（10桁）')),
                const SizedBox(width: 8),
                _FetchBtn(label: '取得', onTap: _fetchASIN),
              ],
            ),
          ],
          const SizedBox(height: 16),

          _FormField(label: 'タイトル *', controller: _titleController, hint: '例：思考の整理学'),
          const SizedBox(height: 14),
          _FormField(label: '著者名', controller: _authorController, hint: '例：外山滋比古'),
          const SizedBox(height: 14),
          _FormField(label: '出版社', controller: _publisherController, hint: '例：ちくま文庫'),
          const SizedBox(height: 14),
          _FormField(label: '総ページ数', controller: _pagesController,
              hint: '例：200', inputType: TextInputType.number),
          const SizedBox(height: 14),
          _FormField(label: '金額', controller: _priceController,
              hint: '例：1650', inputType: TextInputType.number),
          const SizedBox(height: 14),

          // 読書状態
          const _SectionLabel(text: '読書状態'),
          const SizedBox(height: 6),
          _StyledDropdown<String>(
            value: _status,
            items: const [
              DropdownMenuItem(value: 'wish',    child: Text('🌙 読みたい')),
              DropdownMenuItem(value: 'reading', child: Text('📖 読み中')),
              DropdownMenuItem(value: 'stack',   child: Text('📚 積読')),
              DropdownMenuItem(value: 'done',    child: Text('✓ 読了')),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'wish'),
          ),
          if (_status == 'reading') ...[
            const SizedBox(height: 14),
            _FormField(label: '現在のページ', controller: _currentPageController,
                hint: '例：142', inputType: TextInputType.number),
          ],
          const SizedBox(height: 14),

          // タグ（他フィールドと同じ高さ・1本枠）
          const _SectionLabel(text: 'タグ'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bg,
              border: Border.all(color: AppTheme.border, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Wrap(
                      spacing: 6, runSpacing: 4,
                      children: _tags.asMap().entries.map((e) => _TagChip(
                        label: e.value, onRemove: () => _removeTag(e.key))).toList(),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: 'タグを入力…',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: _addTag,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('追加',
                            style: TextStyle(color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // メモ
          const _SectionLabel(text: 'メモ・備考'),
          const SizedBox(height: 6),
          TextField(
            controller: _memoController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'この本についての全体的なメモ、読む動機など…',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),

          // 購入場所
          const _SectionLabel(text: '購入場所'),
          const SizedBox(height: 6),
          _StyledDropdown<String?>(
            value: _purchaseLocations.contains(_purchaseLocation) ? _purchaseLocation : null,
            items: [
              const DropdownMenuItem(value: null, child: Text('選択しない')),
              ..._purchaseLocations.map((loc) =>
                  DropdownMenuItem(value: loc, child: Text(loc))),
            ],
            onChanged: (v) => setState(() => _purchaseLocation = v),
          ),
          const SizedBox(height: 14),

          // 本の種類
          const _SectionLabel(text: '本の種類'),
          const SizedBox(height: 6),
          _StyledDropdown<String?>(
            value: _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
            items: [
              const DropdownMenuItem(value: null, child: Text('選択しない')),
              ..._categories.map((c) =>
                  DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}'))),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('⚙️ 本の種類をカスタマイズ',
                    style: TextStyle(
                      fontSize: 12, color: AppTheme.gold,
                      decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 購入日
          const _SectionLabel(text: '購入日'),
          const SizedBox(height: 6),
          _DatePicker(value: _buyDate, hint: '購入日を選択',
            onChanged: (d) => setState(() => _buyDate = d)),
          const SizedBox(height: 14),

          // 読み始めた日
          const _SectionLabel(text: '読み始めた日'),
          const SizedBox(height: 6),
          _DatePicker(value: _startDate, hint: '読み始めた日を選択',
            onChanged: (d) => setState(() => _startDate = d)),
          const SizedBox(height: 14),

          // 読み終えた日
          const _SectionLabel(text: '読み終えた日'),
          const SizedBox(height: 6),
          _DatePicker(value: _endDate, hint: '読み終えた日を選択',
            onChanged: (d) => setState(() => _endDate = d)),
          const SizedBox(height: 32),

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
                    style: TextStyle(fontSize: 16, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.btnMemo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(_isSaving ? '保存中...' : (isEdit ? '更新する' : '登録する'),
                    style: const TextStyle(
                      fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
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

// 注釈テキスト（グレー）
class _Note extends StatelessWidget {
  final String text;
  const _Note({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary));
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary));
}

class _HintField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  const _HintField({required this.controller, required this.hint,
    this.inputType = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: inputType,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
    ),
  );
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType inputType;
  const _FormField({required this.label, required this.controller,
    required this.hint, this.inputType = TextInputType.text});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(text: label),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
        ),
      ),
    ],
  );
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const _StyledDropdown({required this.value, required this.items, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: AppTheme.bg,
      border: Border.all(color: AppTheme.border, width: 1.5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButton<T>(
      value: value, items: items, onChanged: onChanged,
      isExpanded: true, underline: const SizedBox(),
      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
    ),
  );
}

class _FetchBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _FetchBtn({required this.label, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: onTap != null ? AppTheme.gold : AppTheme.border,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
    ),
  );
}

class _TagChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _TagChip({required this.label, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppTheme.gold, borderRadius: BorderRadius.circular(14)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(width: 4),
        GestureDetector(onTap: onRemove,
          child: const Text('×', style: TextStyle(color: Colors.white, fontSize: 14))),
      ],
    ),
  );
}

class _DatePicker extends StatelessWidget {
  final String? value;
  final String hint;
  final ValueChanged<String?> onChanged;
  const _DatePicker({this.value, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        locale: const Locale('ja', 'JP'),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.gold,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        ),
      );
      if (picked != null) {
        onChanged('${picked.year}年${picked.month}月${picked.day}日');
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        border: Border.all(color: AppTheme.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(value ?? hint,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w300,
                color: value != null ? AppTheme.textPrimary : AppTheme.textSecondary)),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.textSecondary),
        ],
      ),
    ),
  );
}
