// Notion API連携サービス
//
// Flutter Web からの CORS 回避のため、Cloud Functions プロキシが必要です。
// 以下の Cloud Function を functions/index.js にデプロイしてください：
//
// const functions = require('firebase-functions');
// const fetch = require('node-fetch');
// exports.notionProxy = functions.https.onRequest(async (req, res) => {
//   res.set('Access-Control-Allow-Origin', '*');
//   res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
//   res.set('Access-Control-Allow-Headers', 'Content-Type,x-notion-token,x-notion-path,x-notion-method');
//   if (req.method === 'OPTIONS') { res.status(204).send(''); return; }
//   const token = req.headers['x-notion-token'];
//   const path = req.headers['x-notion-path'];
//   const method = (req.headers['x-notion-method'] || 'POST').toUpperCase();
//   const r = await fetch(`https://api.notion.com/v1${path}`, {
//     method,
//     headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json', 'Notion-Version': '2022-06-28' },
//     body: ['POST','PATCH'].includes(method) ? JSON.stringify(req.body) : undefined,
//   });
//   res.status(r.status).json(await r.json());
// });

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notion_config.dart';

class NotionSyncResult {
  final List<Map<String, dynamic>> deletedMemos;
  final int updatedCount;
  final String? pageId;
  final bool isNotConfigured;

  const NotionSyncResult({
    required this.deletedMemos,
    required this.updatedCount,
    this.pageId,
    this.isNotConfigured = false,
  });

  factory NotionSyncResult.notConfigured() => const NotionSyncResult(
    deletedMemos: [],
    updatedCount: 0,
    isNotConfigured: true,
  );
}

class NotionFullSyncResult {
  // bookId → 削除されたメモのリスト
  final Map<String, List<Map<String, dynamic>>> deletedMemosByBook;
  // bookId → notionPageId (syncAll中に確定した値)
  final Map<String, String> pageIdByBook;
  final int totalUpdated;
  final bool isNotConfigured;

  const NotionFullSyncResult({
    required this.deletedMemosByBook,
    required this.pageIdByBook,
    required this.totalUpdated,
    this.isNotConfigured = false,
  });

  factory NotionFullSyncResult.notConfigured() => const NotionFullSyncResult(
    deletedMemosByBook: {},
    pageIdByBook: {},
    totalUpdated: 0,
    isNotConfigured: true,
  );

  bool get hasDeletedMemos => deletedMemosByBook.values.any((l) => l.isNotEmpty);
}

class NotionService {
  static const _notionVersion = '2022-06-28';
  static const _baseUrl = 'https://api.notion.com/v1';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _notionSettingsRef =>
      FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('settings').doc('notion');

  CollectionReference<Map<String, dynamic>> _memosRef(String bookId) =>
      FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('books').doc(bookId)
          .collection('memos');

  // ===== Config =====

  Future<NotionConfig?> loadConfig() async {
    if (_uid == null) return null;
    final doc = await _notionSettingsRef.get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final token = data['token'] as String? ?? '';
    final databaseId = data['databaseId'] as String? ?? '';
    if (token.isEmpty || databaseId.isEmpty) return null;
    return NotionConfig.fromMap(data);
  }

  Future<void> saveConfig(NotionConfig config) async {
    if (_uid == null) return;
    await _notionSettingsRef.set(config.toMap(), SetOptions(merge: true));
  }

  // ===== HTTP =====

  Future<Map<String, dynamic>> _request(
    NotionConfig config,
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final http.Response response;
    const timeout = Duration(seconds: 30);

    if (kIsWeb) {
      if (!config.hasProxy) {
        throw Exception(
          'Flutter Web環境ではCORSプロキシURLが必要です。設定画面でプロキシURLを設定してください。',
        );
      }
      final proxyUri = Uri.parse(config.proxyUrl);
      response = await http
          .post(
            proxyUri,
            headers: {
              'Content-Type': 'application/json',
              'x-notion-token': config.token,
              'x-notion-path': path,
              'x-notion-method': method,
            },
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);
    } else {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        'Authorization': 'Bearer ${config.token}',
        'Content-Type': 'application/json',
        'Notion-Version': _notionVersion,
      };
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(timeout);
        default:
          throw Exception('Unsupported method: $method');
      }
    }

    if (response.statusCode >= 400) {
      final err = _tryParseError(response.body);
      throw Exception('Notion API エラー ${response.statusCode}: $err');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _tryParseError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return m['message'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }

  // ===== Connection test =====

  Future<void> testConnection(NotionConfig config) async {
    await _request(config, 'GET', '/databases/${config.databaseId}');
  }

  // ===== Book page =====

  Future<String> getOrCreateBookPage(
    NotionConfig config,
    String bookTitle,
    String bookId,
  ) async {
    // 既存ページを検索
    final result = await _request(
      config,
      'POST',
      '/databases/${config.databaseId}/query',
      body: {
        'filter': {
          'property': 'title',
          'title': {'equals': bookTitle},
        },
      },
    );
    final results = result['results'] as List;
    if (results.isNotEmpty) {
      return (results.first as Map<String, dynamic>)['id'] as String;
    }

    // 新規作成
    final page = await _request(config, 'POST', '/pages', body: {
      'parent': {'database_id': config.databaseId},
      'properties': {
        'title': {
          'title': [
            {
              'text': {'content': bookTitle},
            },
          ],
        },
      },
    });
    return page['id'] as String;
  }

  // ===== Memo blocks =====

  Future<String> createMemoBlock(
    NotionConfig config,
    String pageId,
    Map<String, dynamic> memoData,
  ) async {
    final text = _formatMemoText(memoData);
    final result = await _request(
      config,
      'PATCH',
      '/blocks/$pageId/children',
      body: {
        'children': [
          {
            'type': 'to_do',
            'to_do': {
              'rich_text': [
                {
                  'type': 'text',
                  'text': {'content': _clampText(text)},
                },
              ],
              'checked': false,
            },
          },
        ],
      },
    );
    final blocks = result['results'] as List;
    return (blocks.first as Map<String, dynamic>)['id'] as String;
  }

  Future<void> updateMemoBlock(
    NotionConfig config,
    String blockId,
    Map<String, dynamic> memoData,
  ) async {
    final text = _formatMemoText(memoData);
    await _request(config, 'PATCH', '/blocks/$blockId', body: {
      'to_do': {
        'rich_text': [
          {
            'type': 'text',
            'text': {'content': _clampText(text)},
          },
        ],
      },
    });
  }

  Future<List<Map<String, dynamic>>> getPageBlocks(
    NotionConfig config,
    String pageId,
  ) async {
    final result = await _request(config, 'GET', '/blocks/$pageId/children');
    final results = result['results'] as List;
    return results.cast<Map<String, dynamic>>();
  }

  // Notion の1ブロックの plain_text を取得
  String _extractNotionBlockText(Map<String, dynamic> block) {
    final type = block['type'] as String? ?? '';
    final blockData = block[type] as Map<String, dynamic>? ?? {};
    final richText = blockData['rich_text'] as List? ?? [];
    return richText
        .map((t) {
          final tMap = t as Map<String, dynamic>;
          return tMap['plain_text'] as String? ??
              (tMap['text'] as Map?)?.entries
                  .firstWhere((e) => e.key == 'content', orElse: () => MapEntry('', ''))
                  .value as String? ??
              '';
        })
        .join('');
  }

  // メモデータをNotionテキスト形式にフォーマット
  // 形式: [type · p.page · importance] content
  String _formatMemoText(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    final page = data['page'] as String? ?? '';
    final importance = data['importance'] as String? ?? '';
    final content = data['content'] as String? ?? '';

    final meta = [
      if (type.isNotEmpty) type,
      if (page.isNotEmpty) 'p.$page',
      if (importance.isNotEmpty) importance,
    ];
    final prefix = meta.isEmpty ? '' : '[${meta.join(' · ')}] ';
    return '$prefix$content';
  }

  // Notionのブロックテキストからcontentを抽出
  // [meta] の後ろを content として取り出す
  String _extractContent(String blockText) {
    final match = RegExp(r'^\[.*?\] (.+)$', dotAll: true).firstMatch(blockText);
    return match?.group(1) ?? blockText;
  }

  // Notion の rich_text は 2000文字制限
  String _clampText(String text) =>
      text.length > 2000 ? text.substring(0, 2000) : text;

  // ===== Single memo sync (push: Firestore → Notion) =====

  Future<void> syncMemoToNotion({
    required String bookId,
    required String memoId,
    required Map<String, dynamic> memoData,
    required String bookTitle,
    required String? currentNotionPageId,
  }) async {
    final config = await loadConfig();
    if (config == null) return;

    // ページ確保
    final String pageId;
    if (currentNotionPageId != null && currentNotionPageId.isNotEmpty) {
      pageId = currentNotionPageId;
    } else {
      pageId = await getOrCreateBookPage(config, bookTitle, bookId);
      await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('books').doc(bookId)
          .update({'notionPageId': pageId});
    }

    // ブロック作成 or 更新
    final existingBlockId = memoData['notionBlockId'] as String?;
    String blockId;

    if (existingBlockId != null && existingBlockId.isNotEmpty) {
      try {
        await updateMemoBlock(config, existingBlockId, memoData);
        blockId = existingBlockId;
      } catch (_) {
        // ブロックが削除されていた場合は再作成
        blockId = await createMemoBlock(config, pageId, memoData);
      }
    } else {
      blockId = await createMemoBlock(config, pageId, memoData);
    }

    await _memosRef(bookId).doc(memoId).update({
      'notionBlockId': blockId,
      'lastSyncedAt': Timestamp.now(),
    });
  }

  // ===== Pull sync for one book (Notion → Firestore) =====

  Future<NotionSyncResult> syncFromNotion({
    required String bookId,
    required String bookTitle,
    required String? notionPageId,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> firestoreMemos,
    required NotionConfig config,
  }) async {
    final String pageId;
    if (notionPageId != null && notionPageId.isNotEmpty) {
      pageId = notionPageId;
    } else {
      pageId = await getOrCreateBookPage(config, bookTitle, bookId);
      await FirebaseFirestore.instance
          .collection('users').doc(_uid)
          .collection('books').doc(bookId)
          .update({'notionPageId': pageId});
    }

    final notionBlocks = await getPageBlocks(config, pageId);
    final notionBlockMap = <String, Map<String, dynamic>>{
      for (final b in notionBlocks) b['id'] as String: b,
    };

    final deletedMemos = <Map<String, dynamic>>[];
    int updatedCount = 0;

    final batch = FirebaseFirestore.instance.batch();
    bool hasBatchOp = false;

    for (final memoDoc in firestoreMemos) {
      final data = memoDoc.data();
      final blockId = data['notionBlockId'] as String?;
      if (blockId == null || blockId.isEmpty) continue;

      if (!notionBlockMap.containsKey(blockId)) {
        // Notionで削除された
        deletedMemos.add({'_id': memoDoc.id, ...data});
      } else {
        // コンテンツ差分チェック（Notion優先）
        final notionText = _extractNotionBlockText(notionBlockMap[blockId]!);
        final expectedText = _formatMemoText(data);
        if (notionText.isNotEmpty && notionText != expectedText) {
          final content = _extractContent(notionText);
          batch.update(_memosRef(bookId).doc(memoDoc.id), {
            'content': content,
            'lastSyncedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
          hasBatchOp = true;
          updatedCount++;
        }
      }
    }

    if (hasBatchOp) await batch.commit();

    return NotionSyncResult(
      deletedMemos: deletedMemos,
      updatedCount: updatedCount,
      pageId: pageId,
    );
  }

  // ===== 削除メモへのアクション =====

  Future<void> deleteMemosFromFirestore(
    String bookId,
    List<String> memoIds,
  ) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in memoIds) {
      batch.delete(_memosRef(bookId).doc(id));
    }
    await batch.commit();
  }

  Future<void> restoreMemosToNotion(
    NotionConfig config,
    String pageId,
    String bookId,
    List<Map<String, dynamic>> memos,
  ) async {
    for (final memo in memos) {
      final memoId = memo['_id'] as String;
      final blockId = await createMemoBlock(config, pageId, memo);
      await _memosRef(bookId).doc(memoId).update({
        'notionBlockId': blockId,
        'lastSyncedAt': Timestamp.now(),
      });
    }
  }

  // ===== Full sync (全書籍対象、手動トリガー) =====

  Future<NotionFullSyncResult> syncAll() async {
    final config = await loadConfig();
    if (config == null) return NotionFullSyncResult.notConfigured();
    final uid = _uid;
    if (uid == null) return NotionFullSyncResult.notConfigured();

    final booksSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('books')
        .get();

    final deletedByBook = <String, List<Map<String, dynamic>>>{};
    final pageIdByBook = <String, String>{};
    int totalUpdated = 0;

    for (final bookDoc in booksSnap.docs) {
      final bookData = bookDoc.data();
      final bookId = bookDoc.id;
      final bookTitle = bookData['title'] as String? ?? '';
      final notionPageId = bookData['notionPageId'] as String?;

      final memosSnap = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('books').doc(bookId)
          .collection('memos')
          .get();

      if (memosSnap.docs.isEmpty) continue;

      // notionBlockId未設定のメモをNotionへプッシュ
      for (final memoDoc in memosSnap.docs) {
        final memoData = memoDoc.data();
        if ((memoData['notionBlockId'] as String?) != null) continue;
        try {
          await syncMemoToNotion(
            bookId: bookId,
            memoId: memoDoc.id,
            memoData: memoData,
            bookTitle: bookTitle,
            currentNotionPageId: bookData['notionPageId'] as String?,
          );
        } catch (_) {}
      }

      // 最新のnotionPageIdを再取得（push中に更新されている可能性あり）
      final refreshed = await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('books').doc(bookId)
          .get();
      final latestPageId =
          refreshed.data()?['notionPageId'] as String? ?? notionPageId;

      try {
        final result = await syncFromNotion(
          bookId: bookId,
          bookTitle: bookTitle,
          notionPageId: latestPageId,
          firestoreMemos: memosSnap.docs,
          config: config,
        );
        if (result.pageId != null) pageIdByBook[bookId] = result.pageId!;
        if (result.deletedMemos.isNotEmpty) {
          deletedByBook[bookId] = result.deletedMemos;
        }
        totalUpdated += result.updatedCount;
      } catch (_) {}
    }

    return NotionFullSyncResult(
      deletedMemosByBook: deletedByBook,
      pageIdByBook: pageIdByBook,
      totalUpdated: totalUpdated,
    );
  }
}
