import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';
import '../services/notion_service.dart';
import 'settings_screen.dart';

class MemoFormScreen extends StatefulWidget {
  final List<Book> books;
  final String? initialBookId;
  // 編集モード用
  final String? memoId;
  final Map<String, dynamic>? existingMemo;
  // コピーモード用
  final bool isCopy;

  const MemoFormScreen({
    super.key,
    required this.books,
    this.initialBookId,
    this.memoId,
    this.existingMemo,
    this.isCopy = false,
  });

  @override
  State<MemoFormScreen> createState() => _MemoFormScreenState();
}

class _MemoFormScreenState extends State<MemoFormScreen> {
  late String? _selectedBookId;
  final _pageController = TextEditingController();
  final _contentController = TextEditingController();
  final _speakerController = TextEditingController();
  final _topicController = TextEditingController();
  String _memoType = '';
  String _importance = '';
  bool _isSaving = false;

  List<Map<String, String>> _memoTypes = [];
  List<Map<String, String>> _importanceTags = [];

  final _notionService = NotionService();

  bool get _isEdit => widget.memoId != null;

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.initialBookId ??
        (widget.books.isNotEmpty ? widget.books.first.id : null);
    // 編集・コピーモードの場合、既存データをセット
    if ((_isEdit || widget.isCopy) && widget.existingMemo != null) {
      final m = widget.existingMemo!;
      _pageController.text = m['page'] ?? '';
      _contentController.text = m['content'] ?? '';
      _speakerController.text = m['speaker'] ?? '';
      _topicController.text = m['topic'] ?? '';
      _memoType = m['type'] ?? '';
      _importance = m['importance'] ?? '';
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final types = await SettingsService.getMemoTypes();
    final tags = await SettingsService.getImportanceTags();
    setState(() {
      _memoTypes = types;
      _importanceTags = tags;
      // 編集モードで既存の種類・タグを選択状態に
      if (_isEdit) {
        // typeとimportanceはすでにセット済み
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contentController.dispose();
    _speakerController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedBookId == null) return _snack('本を選択してください');
    if (_contentController.text.trim().isEmpty) return _snack('メモ内容を入力してください');
    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final memoData = {
        'page': _pageController.text.trim(),
        'type': _memoType,
        'importance': _importance,
        'speaker': _speakerController.text.trim(),
        'topic': _topicController.text.trim(),
        'content': _contentController.text.trim(),
        'updatedAt': Timestamp.now(),
      };

      String savedMemoId;
      Map<String, dynamic> savedMemoData;

      if (_isEdit) {
        await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('books').doc(_selectedBookId)
            .collection('memos').doc(widget.memoId)
            .update(memoData);
        savedMemoId = widget.memoId!;
        // 既存のnotionBlockIdをマージして取得
        final existing = widget.existingMemo ?? {};
        savedMemoData = {...existing, ...memoData};
      } else {
        final pageNum = int.tryParse(_pageController.text.trim());
        final sortOrder = pageNum != null ? pageNum * 1000 : 999999000;
        final ref = await FirebaseFirestore.instance
            .collection('users').doc(uid)
            .collection('books').doc(_selectedBookId)
            .collection('memos').add({
          ...memoData,
          'sortOrder': sortOrder,
          'createdAt': Timestamp.now(),
        });
        savedMemoId = ref.id;
        savedMemoData = memoData;
      }

      if (!mounted) return;
      _snack(_isEdit ? 'メモを更新しました' : 'メモを保存しました');
      Navigator.pop(context);

      // Notion同期（バックグラウンド、失敗しても画面には戻らない）
      _syncToNotion(uid, savedMemoId, savedMemoData);
    } catch (e) {
      if (mounted) _snack('保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncToNotion(
    String uid,
    String memoId,
    Map<String, dynamic> memoData,
  ) async {
    final bookId = _selectedBookId;
    if (bookId == null) return;

    // 対象の本を探す
    final book = widget.books.where((b) => b.id == bookId).firstOrNull;
    if (book == null) return;

    try {
      await _notionService.syncMemoToNotion(
        bookId: bookId,
        memoId: memoId,
        memoData: memoData,
        bookTitle: book.title,
        currentNotionPageId: book.notionPageId,
      );
    } catch (e) {
      // Notion未設定の場合は静かにスキップ
      final msg = e.toString();
      if (msg.contains('プロキシ') || msg.contains('設定')) return;
      // それ以外のエラーはグローバルSnackBarで通知（contextが無効な場合はスキップ）
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _openSettings() async {
    await Navigator.push(context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()));
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBg,
        title: Text(_isEdit ? '✏️ メモを編集' : widget.isCopy ? '📋 メモをコピー' : '📝 メモを追加',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('保存する',
              style: TextStyle(color: AppTheme.gold, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
        children: [
          const _Label(text: '本のタイトル *'),
          const SizedBox(height: 6),
          if (widget.books.isEmpty)
            const Text('本が登録されていません',
              style: TextStyle(color: AppTheme.textSecondary))
          else
            _StyledDropdown<String>(
              value: _selectedBookId ?? widget.books.first.id,
              items: widget.books.map((b) => DropdownMenuItem(
                value: b.id,
                child: Text(b.title, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _selectedBookId = v),
            ),
          const SizedBox(height: 16),
          const _Label(text: 'ページ番号'),
          const SizedBox(height: 6),
          TextField(
            controller: _pageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '例：142',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
            ),
          ),
          const SizedBox(height: 16),
          const _Label(text: 'メモの種類'),
          const SizedBox(height: 6),
          _StyledDropdown<String>(
            value: _memoType,
            items: [
              const DropdownMenuItem(value: '', child: Text('（なし）')),
              ..._memoTypes.map((t) => DropdownMenuItem(
                value: '${t['emoji']} ${t['name']}',
                child: Text('${t['emoji']} ${t['name']}'))),
            ],
            onChanged: (v) => setState(() => _memoType = v ?? ''),
          ),
          const SizedBox(height: 16),
          const _Label(text: '重要度タグ'),
          const SizedBox(height: 6),
          _StyledDropdown<String>(
            value: _importance,
            items: [
              const DropdownMenuItem(value: '', child: Text('なし')),
              ..._importanceTags.map((t) => DropdownMenuItem(
                value: '${t['emoji']} ${t['name']}',
                child: Text('${t['emoji']} ${t['name']}'))),
            ],
            onChanged: (v) => setState(() => _importance = v ?? ''),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openSettings,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('⚙️ 種類・タグをカスタマイズ',
                    style: TextStyle(
                      fontSize: 12, color: AppTheme.gold,
                      decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Label(text: '発言者'),
          const SizedBox(height: 6),
          TextField(
            controller: _speakerController,
            decoration: const InputDecoration(
              hintText: '例：田中一郎、著者、登場人物など',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
            ),
          ),
          const SizedBox(height: 16),
          const _Label(text: '作中のトピック'),
          const SizedBox(height: 6),
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              hintText: '例：本に登場した本の名前、音楽名、参考資料など',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
            ),
          ),
          const SizedBox(height: 16),
          const _Label(text: 'メモ内容 *'),
          const SizedBox(height: 6),
          TextField(
            controller: _contentController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'ここにメモを書いてください…',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
              alignLabelWithHint: true,
            ),
          ),
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
                  child: Text(_isSaving ? '保存中...' : (_isEdit ? '更新する' : '保存する'),
                    style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary));
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
