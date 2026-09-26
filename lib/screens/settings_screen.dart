import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notion_service.dart';
import '../models/category.dart';
import '../models/notion_config.dart';
import '../theme/app_theme.dart';
import '../utils/url_utils.dart';
import '../utils/pwa_install.dart';
import '../widgets/notion_deleted_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final bool embedded;
  const SettingsScreen({super.key, this.embedded = false});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  static const _platform = MethodChannel('com.yamaguchi.shiori/browser');

  bool _purchaseExpanded = false;
  bool _memoTypesExpanded = false;
  bool _importanceTagsExpanded = false;
  bool _categoryExpanded = false;
  bool _notionExpanded = false;

  // Notion設定
  final _notionTokenCtrl = TextEditingController();
  final _notionDbIdCtrl = TextEditingController();
  final _notionProxyCtrl = TextEditingController();
  bool _notionTokenVisible = false;
  bool _notionTesting = false;
  bool _notionSyncing = false;
  final _notionService = NotionService();

  // メモ種類リスト
  List<Map<String, String>> _memoTypes = [
    {'emoji': '👤', 'name': '人物メモ'},
    {'emoji': '📖', 'name': '読み方メモ'},
    {'emoji': '✏️', 'name': '引用'},
    {'emoji': '💡', 'name': '気づき'},
    {'emoji': '❓', 'name': '疑問'},
  ];

  // 重要度タグリスト
  List<Map<String, String>> _importanceTags = [
    {'emoji': '📌', 'name': '重要'},
    {'emoji': '❓', 'name': '疑問'},
    {'emoji': '😮', 'name': '驚き'},
    {'emoji': '⭐', 'name': 'お気に入り'},
  ];

  // 購入場所リスト
  List<String> _purchaseLocations = [...FirestoreService.defaultPurchaseLocations];

  final _newTypeEmojiCtrl = TextEditingController();
  final _newTypeNameCtrl = TextEditingController();
  final _newTagEmojiCtrl = TextEditingController();
  final _newTagNameCtrl = TextEditingController();
  final _newLocationCtrl = TextEditingController();
  final _newCategoryEmojiCtrl = TextEditingController();
  final _newCategoryNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _firestoreService.initDefaultCategories();
    _loadNotionConfig();
  }

  @override
  void dispose() {
    _newTypeEmojiCtrl.dispose();
    _newTypeNameCtrl.dispose();
    _newTagEmojiCtrl.dispose();
    _newTagNameCtrl.dispose();
    _newLocationCtrl.dispose();
    _newCategoryEmojiCtrl.dispose();
    _newCategoryNameCtrl.dispose();
    _notionTokenCtrl.dispose();
    _notionDbIdCtrl.dispose();
    _notionProxyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final locations = await _firestoreService.getPurchaseLocations();
    setState(() {
      final typesJson = prefs.getStringList('memoTypes');
      if (typesJson != null && typesJson.isNotEmpty) {
        _memoTypes = typesJson.map((s) {
          final parts = s.split('||');
          return {'emoji': parts[0], 'name': parts.length > 1 ? parts[1] : ''};
        }).toList();
      }
      final tagsJson = prefs.getStringList('importanceTags');
      if (tagsJson != null && tagsJson.isNotEmpty) {
        _importanceTags = tagsJson.map((s) {
          final parts = s.split('||');
          return {'emoji': parts[0], 'name': parts.length > 1 ? parts[1] : ''};
        }).toList();
      }
      _purchaseLocations = locations;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('memoTypes',
      _memoTypes.map((m) => '${m['emoji']}||${m['name']}').toList());
    await prefs.setStringList('importanceTags',
      _importanceTags.map((t) => '${t['emoji']}||${t['name']}').toList());
    await _firestoreService.savePurchaseLocations(_purchaseLocations);
    await _saveNotionConfig();
    if (mounted) {
      if (!widget.embedded) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')));
    }
  }

  // ユーザー名をマスク表示
  String get _maskedName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '不明';
    final raw = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.email?.split('@').first ?? '不明');
    if (raw.length <= 3) return '$raw****さん';
    return '${raw.substring(0, 3)}****さん';
  }

  Future<void> _createShortcut() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text(
          'ショートカットを追加',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1006),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB8860B), width: 1.5),
              ),
              child: const Center(
                child: Text('栞',
                  style: TextStyle(
                    fontSize: 36,
                    color: Color(0xFFB8860B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ホーム画面に栞のショートカットを追加しますか？',
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('追加する',
              style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (kIsWeb) {
      final added = await triggerPwaInstall();
      if (!mounted) return;
      if (!added) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ブラウザのメニュー（⋮）→「ホーム画面に追加」から追加できます'),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      Uint8List? iconBytes;
      try {
        final data = await rootBundle.load('assets/icon/shiori_icon_rounded.png');
        iconBytes = data.buffer.asUint8List();
      } catch (_) {
        // アイコンファイルが未配置の場合はネイティブ側のランチャーアイコンを使用
      }
      final result = await _platform.invokeMethod<bool>(
        'createShortcut',
        iconBytes != null ? {'iconBytes': iconBytes} : null,
      );
      if (!mounted) return;
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ホーム画面にショートカットを追加しました')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お使いの端末ではショートカット作成に対応していません')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')));
    }
  }

  Future<void> _loadNotionConfig() async {
    final config = await _notionService.loadConfig();
    if (config != null && mounted) {
      setState(() {
        _notionTokenCtrl.text = config.token;
        _notionDbIdCtrl.text = config.databaseId;
        _notionProxyCtrl.text = config.proxyUrl;
      });
    }
  }

  Future<void> _saveNotionConfig() async {
    final token = _notionTokenCtrl.text.trim();
    final dbId = _notionDbIdCtrl.text.trim();
    final proxy = _notionProxyCtrl.text.trim();
    await _notionService.saveConfig(
      NotionConfig(token: token, databaseId: dbId, proxyUrl: proxy),
    );
  }

  Future<void> _testNotionConnection() async {
    final token = _notionTokenCtrl.text.trim();
    final dbId = _notionDbIdCtrl.text.trim();
    final proxy = _notionProxyCtrl.text.trim();
    if (token.isEmpty || dbId.isEmpty) {
      _snack('Integration TokenとDatabase IDを入力してください');
      return;
    }
    setState(() => _notionTesting = true);
    try {
      final config = NotionConfig(token: token, databaseId: dbId, proxyUrl: proxy);
      await _notionService.testConnection(config);
      if (mounted) _snack('Notion接続に成功しました');
    } catch (e) {
      if (mounted) _snack('接続に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _notionTesting = false);
    }
  }

  Future<void> _syncAllWithNotion() async {
    await _saveNotionConfig();
    setState(() => _notionSyncing = true);
    try {
      final result = await _notionService.syncAll();
      if (!mounted) return;

      if (result.isNotConfigured) {
        _snack('Notion設定が未完了です。TokenとDatabase IDを入力してください');
        return;
      }

      // 削除されたメモがある書籍ごとにダイアログ表示
      for (final entry in result.deletedMemosByBook.entries) {
        final bookId = entry.key;
        final deletedMemos = entry.value;
        final pageId = result.pageIdByBook[bookId] ?? '';
        if (!mounted) break;

        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NotionDeletedDialog(
            deletedMemos: deletedMemos,
            onKeepInShiori: () async {
              // notionBlockIdをクリア（栞側に残す＝Notionとのリンク解除）
              final batch = FirebaseFirestore.instance.batch();
              for (final memo in deletedMemos) {
                final memoId = memo['_id'] as String;
                final ref = FirebaseFirestore.instance
                    .collection('users').doc(FirebaseAuth.instance.currentUser?.uid)
                    .collection('books').doc(bookId)
                    .collection('memos').doc(memoId);
                batch.update(ref, {'notionBlockId': null, 'lastSyncedAt': null});
              }
              await batch.commit();
            },
            onDeleteFromShiori: () async {
              final ids = deletedMemos.map((m) => m['_id'] as String).toList();
              await _notionService.deleteMemosFromFirestore(bookId, ids);
            },
            onRestoreToNotion: () async {
              if (pageId.isEmpty) return;
              final config = await _notionService.loadConfig();
              if (config == null) return;
              await _notionService.restoreMemosToNotion(
                config, pageId, bookId, deletedMemos,
              );
            },
          ),
        );
      }

      final updated = result.totalUpdated;
      final deletedBooks = result.deletedMemosByBook.length;
      if (updated == 0 && deletedBooks == 0) {
        _snack('Notionと同期しました（差分なし）');
      } else {
        _snack('同期完了：${updated}件更新、削除メモ処理済み');
      }
    } catch (e) {
      if (mounted) _snack('同期に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _notionSyncing = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  void _openUrl(String url) => openExternalUrl(url);

  Future<void> _confirmDeleteAccount() async {
    // 1回目の確認
    final first = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('アカウントを削除'),
        content: const Text(
          'アカウントを削除すると、すべての読書データ・メモが完全に削除されます。\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('次へ', style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (first != true || !mounted) return;

    // 2回目の確認
    final second = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('本当に削除しますか？'),
        content: const Text('Googleアカウントの再認証が必要です。\n確認後、アカウントとすべてのデータを削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('削除する', style: TextStyle(color: Colors.red.shade600,
              fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (second != true || !mounted) return;

    // 削除実行
    final loading = showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('削除中...'),
          ],
        ),
      ),
    );

    final success = await _authService.deleteAccount();
    if (mounted) Navigator.of(context, rootNavigator: true).pop(); // loading閉じる

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('削除に失敗しました。再度お試しください。'),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _showCategoryEditDialog({Category? existing}) async {
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          existing == null ? '本の種類を追加' : '本の種類を編集',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        content: Row(
          children: [
            SizedBox(
              width: 54,
              child: TextField(
                controller: emojiCtrl,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  hintText: '📁',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  filled: true, fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border)),
                ),
                maxLength: 2,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: '本の種類名',
                  hintStyle: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true, fillColor: AppTheme.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border)),
                ),
                maxLength: 20,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final emoji = emojiCtrl.text.trim().isEmpty ? '📁' : emojiCtrl.text.trim();
    if (existing == null) {
      await _firestoreService.addCategory(Category(id: '', name: name, emoji: emoji, createdAt: DateTime.now()));
    } else {
      await _firestoreService.updateCategory(existing.copyWith(name: name, emoji: emoji));
    }
  }

  Future<void> _confirmCategoryDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('本の種類を削除', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '「${category.emoji} ${category.name}」を削除しますか？\nこの本の種類に紐付けられた本の種類は未設定になります。',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _firestoreService.deleteCategory(category.id);
  }

  Future<bool> _confirmDelete(String label) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('削除の確認', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('「$label」を削除しますか？', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _openContact() => _openUrl('https://shiori-official.digitalhack-note.com#contact');
  void _openAbout() => _openUrl('https://shiori-official.digitalhack-note.com');

  void _addMemoType() {
    final emoji = _newTypeEmojiCtrl.text.trim();
    final name = _newTypeNameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_memoTypes.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最大20種類です')));
      return;
    }
    setState(() {
      _memoTypes.add({'emoji': emoji.isEmpty ? '📝' : emoji, 'name': name});
      _newTypeEmojiCtrl.clear();
      _newTypeNameCtrl.clear();
    });
  }

  void _deleteMemoType(int i) => setState(() => _memoTypes.removeAt(i));

  void _addImportanceTag() {
    final emoji = _newTagEmojiCtrl.text.trim();
    final name = _newTagNameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_importanceTags.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最大20個です')));
      return;
    }
    setState(() {
      _importanceTags.add({'emoji': emoji.isEmpty ? '🏷️' : emoji, 'name': name});
      _newTagEmojiCtrl.clear();
      _newTagNameCtrl.clear();
    });
  }

  void _deleteImportanceTag(int i) => setState(() => _importanceTags.removeAt(i));

  Future<void> _addCategory() async {
    final name = _newCategoryNameCtrl.text.trim();
    if (name.isEmpty) return;
    final emoji = _newCategoryEmojiCtrl.text.trim().isEmpty ? '📁' : _newCategoryEmojiCtrl.text.trim();
    await _firestoreService.addCategory(Category(id: '', name: name, emoji: emoji, createdAt: DateTime.now()));
    _newCategoryEmojiCtrl.clear();
    _newCategoryNameCtrl.clear();
  }

  void _addLocation() {
    final name = _newLocationCtrl.text.trim();
    if (name.isEmpty) return;
    if (_purchaseLocations.contains(name)) return;
    if (_purchaseLocations.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最大20件です')));
      return;
    }
    setState(() {
      _purchaseLocations.add(name);
      _newLocationCtrl.clear();
    });
  }

  void _deleteLocation(int i) => setState(() => _purchaseLocations.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final body = ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ===== アカウント =====
          _Section(
            title: '👤 アカウント',
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle, size: 32, color: AppTheme.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_maskedName,
                          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await _authService.signOut();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF888888)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('ログアウト',
                                style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _confirmDeleteAccount,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red.shade300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('アカウント削除',
                                style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading: const Text('📱', style: TextStyle(fontSize: 20)),
                  title: const Text('ホーム画面にショートカットを追加',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('タップしてアイコンをホーム画面に作成',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.add_to_home_screen, color: AppTheme.gold),
                  onTap: _createShortcut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== 購入場所 =====
          _Section(
            title: '🏪 購入場所',
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🏪', style: TextStyle(fontSize: 20)),
                  title: const Text('購入場所を管理',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('追加・編集・並び替え',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: AnimatedRotation(
                    turns: _purchaseExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ),
                  onTap: () => setState(() => _purchaseExpanded = !_purchaseExpanded),
                ),
                if (_purchaseExpanded) ...[
                  const Divider(height: 1, color: AppTheme.border),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text('長押しでドラッグ&ドロップ並び替え。最大20件。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  ReorderableListView(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      setState(() {
                        final item = _purchaseLocations.removeAt(oldIndex);
                        _purchaseLocations.insert(newIndex, item);
                      });
                    },
                    children: _purchaseLocations.asMap().entries.map((e) {
                      final i = e.key;
                      return _LocationItem(
                        key: ValueKey('loc_$i'),
                        index: i,
                        name: e.value,
                        onNameChanged: (v) => setState(() => _purchaseLocations[i] = v),
                        onDelete: () async {
                          if (await _confirmDelete(e.value)) _deleteLocation(i);
                        },
                      );
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newLocationCtrl,
                            decoration: const InputDecoration(
                              hintText: '購入場所を入力（例：メルカリ）',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (_) => _addLocation(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addLocation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('追加',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== メモの種類 =====
          _Section(
            title: '📝 メモの種類',
            child: Column(
              children: [
                ListTile(
                  leading: const Text('📝', style: TextStyle(fontSize: 20)),
                  title: const Text('メモの種類を管理',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('追加・編集・並び替え',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: AnimatedRotation(
                    turns: _memoTypesExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ),
                  onTap: () => setState(() => _memoTypesExpanded = !_memoTypesExpanded),
                ),
                if (_memoTypesExpanded) ...[
                  const Divider(height: 1, color: AppTheme.border),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text('長押しでドラッグ&ドロップ並び替え。最大20種類。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  ReorderableListView(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      setState(() {
                        final item = _memoTypes.removeAt(oldIndex);
                        _memoTypes.insert(newIndex, item);
                      });
                    },
                    children: _memoTypes.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return _CustomizeItem(
                        key: ValueKey('memo_$i'),
                        index: i,
                        emoji: item['emoji'] ?? '',
                        name: item['name'] ?? '',
                        onEmojiChanged: (v) => setState(() => _memoTypes[i]['emoji'] = v),
                        onNameChanged: (v) => setState(() => _memoTypes[i]['name'] = v),
                        onDelete: () async {
                          if (await _confirmDelete(item['name'] ?? '')) _deleteMemoType(i);
                        },
                      );
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _newTypeEmojiCtrl,
                            textAlign: TextAlign.left,
                            decoration: const InputDecoration(
                              hintText: '📝',
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            maxLength: 2,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _newTypeNameCtrl,
                            decoration: const InputDecoration(
                              hintText: '種類名（例：感想）',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            maxLength: 10,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addMemoType,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('追加',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== 重要度タグ =====
          _Section(
            title: '🏷️ 重要度タグ',
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🏷️', style: TextStyle(fontSize: 20)),
                  title: const Text('重要度タグを管理',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('追加・編集・並び替え',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: AnimatedRotation(
                    turns: _importanceTagsExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ),
                  onTap: () => setState(() => _importanceTagsExpanded = !_importanceTagsExpanded),
                ),
                if (_importanceTagsExpanded) ...[
                  const Divider(height: 1, color: AppTheme.border),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Text('長押しでドラッグ&ドロップ並び替え。最大20個。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                  ReorderableListView(
                    buildDefaultDragHandles: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      setState(() {
                        final item = _importanceTags.removeAt(oldIndex);
                        _importanceTags.insert(newIndex, item);
                      });
                    },
                    children: _importanceTags.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return _CustomizeItem(
                        key: ValueKey('tag_$i'),
                        index: i,
                        emoji: item['emoji'] ?? '',
                        name: item['name'] ?? '',
                        onEmojiChanged: (v) => setState(() => _importanceTags[i]['emoji'] = v),
                        onNameChanged: (v) => setState(() => _importanceTags[i]['name'] = v),
                        onDelete: () async {
                          if (await _confirmDelete(item['name'] ?? '')) _deleteImportanceTag(i);
                        },
                      );
                    }).toList(),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _newTagEmojiCtrl,
                            textAlign: TextAlign.left,
                            decoration: const InputDecoration(
                              hintText: '🏷️',
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            maxLength: 2,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _newTagNameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'タグ名（例：感動）',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            maxLength: 10,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _addImportanceTag,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('追加',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== 本の種類 =====
          _Section(
            title: '🗂️ 本の種類',
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🗂️', style: TextStyle(fontSize: 20)),
                  title: const Text('本の種類を管理',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('追加・編集・並び替え',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: AnimatedRotation(
                    turns: _categoryExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ),
                  onTap: () => setState(() => _categoryExpanded = !_categoryExpanded),
                ),
                if (_categoryExpanded) ...[
                  const Divider(height: 1, color: AppTheme.border),
                  StreamBuilder<List<Category>>(
                    stream: _firestoreService.categoriesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
                        );
                      }
                      final categories = snapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
                            child: Center(
                              child: Text(
                                '長押しでドラッグ＆ドロップ並び替え。',
                                textAlign: TextAlign.left,
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6),
                              ),
                            ),
                          ),
                          ReorderableListView(
                            buildDefaultDragHandles: false,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) newIndex--;
                              final updated = List<Category>.from(categories);
                              final item = updated.removeAt(oldIndex);
                              updated.insert(newIndex, item);
                              await _firestoreService.updateCategorySortOrders(updated);
                            },
                            children: categories.asMap().entries.map((e) {
                              final cat = e.value;
                              return _SettingsCategoryItem(
                              key: ValueKey(cat.id),
                              index: e.key,
                              category: cat,
                              onEmojiChanged: (v) {
                                final emoji = v.trim().isEmpty ? '📁' : v.trim();
                                _firestoreService.updateCategory(cat.copyWith(emoji: emoji));
                              },
                              onNameChanged: (v) {
                                if (v.trim().isNotEmpty) {
                                  _firestoreService.updateCategory(cat.copyWith(name: v.trim()));
                                }
                              },
                              onDelete: () => _confirmCategoryDelete(cat),
                            );}).toList(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 50,
                                  child: TextField(
                                    controller: _newCategoryEmojiCtrl,
                                    textAlign: TextAlign.left,
                                    decoration: const InputDecoration(
                                      hintText: '📁',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                    ),
                                    maxLength: 2,
                                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _newCategoryNameCtrl,
                                    decoration: const InputDecoration(
                                      hintText: '本の種類名（例：小説）',
                                      hintStyle: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    maxLength: 20,
                                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                                    onSubmitted: (_) => _addCategory(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _addCategory,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('追加',
                                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== このサービスについて =====
          _Section(
            title: 'ℹ️ このサービスについて',
            child: Column(
              children: [
                ListTile(
                  leading: const Text('📖', style: TextStyle(fontSize: 20)),
                  title: const Text('栞 (SHIORI)',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('バージョン情報など',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: _openAbout,
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading: const Text('📮', style: TextStyle(fontSize: 20)),
                  title: const Text('お問合せ',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('バグ報告・ご不明点など',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: _openContact,
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading: const Text('🔒', style: TextStyle(fontSize: 20)),
                  title: const Text('プライバシーポリシー',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () => _openUrl('https://shiori-official.digitalhack-note.com#privacy'),
                ),
                const Divider(height: 1, color: AppTheme.border),
                ListTile(
                  leading: const Text('📄', style: TextStyle(fontSize: 20)),
                  title: const Text('利用規約',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onTap: () => _openUrl('https://shiori-official.digitalhack-note.com#terms'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== Notion連携 =====
          _Section(
            title: '🔗 Notion連携',
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🔗', style: TextStyle(fontSize: 20)),
                  title: const Text('Notionと読書メモを同期',
                    style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                  subtitle: const Text('Integration TokenとDatabase IDを設定',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: AnimatedRotation(
                    turns: _notionExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ),
                  onTap: () => setState(() => _notionExpanded = !_notionExpanded),
                ),
                if (_notionExpanded) ...[
                  const Divider(height: 1, color: AppTheme.border),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Integration Token
                        const Text('Integration Token',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _notionTokenCtrl,
                          obscureText: !_notionTokenVisible,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'secret_xxxxxxxxxxxxxxxx',
                            hintStyle: const TextStyle(
                              color: AppTheme.textSecondary, fontWeight: FontWeight.w300, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true, fillColor: AppTheme.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.border)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _notionTokenVisible ? Icons.visibility_off : Icons.visibility,
                                size: 18, color: AppTheme.textSecondary),
                              onPressed: () =>
                                setState(() => _notionTokenVisible = !_notionTokenVisible),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Database ID
                        const Text('Database ID',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _notionDbIdCtrl,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                            hintStyle: const TextStyle(
                              color: AppTheme.textSecondary, fontWeight: FontWeight.w300, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true, fillColor: AppTheme.bg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.border)),
                          ),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 12),
                          // Web用プロキシURL
                          Row(
                            children: [
                              const Text('CORSプロキシURL（Web必須）',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Flutter WebはNotion APIに直接アクセスできません。\n'
                                    'Cloud FunctionsなどのCORSプロキシURLを入力してください。\n'
                                    '設定方法はnotion_service.dartのコメントを参照。',
                                child: const Icon(Icons.help_outline,
                                  size: 14, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _notionProxyCtrl,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'https://us-central1-xxx.cloudfunctions.net/notionProxy',
                              hintStyle: const TextStyle(
                                color: AppTheme.textSecondary, fontWeight: FontWeight.w300, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true, fillColor: AppTheme.bg,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: AppTheme.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: AppTheme.border)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // ボタン行
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _notionTesting ? null : _testNotionConnection,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: AppTheme.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _notionTesting
                                    ? const SizedBox(
                                        height: 16, width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppTheme.textSecondary))
                                    : const Text('接続テスト',
                                        style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _notionSyncing ? null : _syncAllWithNotion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.btnMemo,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _notionSyncing
                                    ? const SizedBox(
                                        height: 16, width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                    : const Text('全件同期',
                                        style: TextStyle(fontSize: 13, color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '「全件同期」で設定を保存してNotionと双方向同期します。\nメモ保存時は自動でNotionへ反映されます。',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ===== データ =====
          _Section(
            title: '📤 データ',
            child: ListTile(
              leading: const Text('📚', style: TextStyle(fontSize: 20)),
              title: const Text('本の情報をエクスポート',
                style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              subtitle: const Text('本の情報とメモの内容をすべてエクスポートできます（準備中）',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('エクスポート'),
                  content: const Text('この機能は近日公開予定です。'),
                  actions: [TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'))],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ボタン行
          Row(
            children: [
              if (!widget.embedded) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('戻る',
                      style: TextStyle(fontSize: 16, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.btnMemo,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('保存する',
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBg,
        title: const Text('⚙️ 設定',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存',
              style: TextStyle(color: AppTheme.gold, fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: body,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ),
        const Divider(height: 1, color: AppTheme.border),
        child,
      ],
    ),
  );
}

class _LocationItem extends StatelessWidget {
  final int index;
  final String name;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;

  const _LocationItem({
    super.key,
    required this.index,
    required this.name,
    required this.onNameChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: name,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            ),
            onChanged: onNameChanged,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('削除',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
      ],
    ),
  );
}

class _CustomizeItem extends StatelessWidget {
  final int index;
  final String emoji;
  final String name;
  final ValueChanged<String> onEmojiChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;

  const _CustomizeItem({
    super.key,
    required this.index,
    required this.emoji, required this.name,
    required this.onEmojiChanged, required this.onNameChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: TextFormField(
            initialValue: emoji,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            ),
            maxLength: 2,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: onEmojiChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: name,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            ),
            maxLength: 10,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: onNameChanged,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('削除',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCategoryItem extends StatelessWidget {
  final int index;
  final Category category;
  final ValueChanged<String> onEmojiChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;

  const _SettingsCategoryItem({
    super.key,
    required this.index,
    required this.category,
    required this.onEmojiChanged,
    required this.onNameChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 20),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: TextFormField(
            initialValue: category.emoji,
            textAlign: TextAlign.left,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            ),
            maxLength: 2,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: onEmojiChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: category.name,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true, fillColor: AppTheme.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border)),
            ),
            maxLength: 20,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            onChanged: onNameChanged,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('削除', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
        ),
      ],
    ),
  );
}

// 設定を読み込むユーティリティ（他画面から呼ぶ）
class SettingsService {
  static Future<List<Map<String, String>>> getMemoTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('memoTypes');
    if (list == null || list.isEmpty) {
      return [
        {'emoji': '👤', 'name': '人物メモ'},
        {'emoji': '📖', 'name': '読み方メモ'},
        {'emoji': '✏️', 'name': '引用'},
        {'emoji': '💡', 'name': '気づき'},
        {'emoji': '❓', 'name': '疑問'},
      ];
    }
    return list.map((s) {
      final parts = s.split('||');
      return {'emoji': parts[0], 'name': parts.length > 1 ? parts[1] : ''};
    }).toList();
  }

  static Future<List<Map<String, String>>> getImportanceTags() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('importanceTags');
    if (list == null || list.isEmpty) {
      return [
        {'emoji': '📌', 'name': '重要'},
        {'emoji': '❓', 'name': '疑問'},
        {'emoji': '😮', 'name': '驚き'},
        {'emoji': '⭐', 'name': 'お気に入り'},
      ];
    }
    return list.map((s) {
      final parts = s.split('||');
      return {'emoji': parts[0], 'name': parts.length > 1 ? parts[1] : ''};
    }).toList();
  }
}
