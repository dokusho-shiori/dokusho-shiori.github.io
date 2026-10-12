import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/models/book.dart';
import 'package:shiori/utils/link_utils.dart';

void main() {
  group('normalizeLinkUrl（関連リンクの入力チェック）', () {
    test('http / https のURLはそのまま通す', () {
      expect(normalizeLinkUrl('https://www.notion.so/abc123'),
          'https://www.notion.so/abc123');
      expect(normalizeLinkUrl('http://example.com/a?b=1#c'),
          'http://example.com/a?b=1#c');
    });

    test('前後の空白は取り除く', () {
      expect(normalizeLinkUrl('  https://example.com/x \n'),
          'https://example.com/x');
    });

    test('空欄・null はリンクなし（null）', () {
      expect(normalizeLinkUrl(null), isNull);
      expect(normalizeLinkUrl(''), isNull);
      expect(normalizeLinkUrl('   '), isNull);
    });

    test('http(s) 以外や壊れたURLは受け付けない', () {
      expect(normalizeLinkUrl('javascript:alert(1)'), isNull);
      expect(normalizeLinkUrl('data:text/html,<b>x</b>'), isNull);
      expect(normalizeLinkUrl('notion://www.notion.so/abc'), isNull);
      expect(normalizeLinkUrl('www.notion.so/abc'), isNull);
      expect(normalizeLinkUrl('https://'), isNull);
      expect(normalizeLinkUrl('https://example.com/a b'), isNull);
    });
  });

  group('linkOpenLabel（ボタンの表示名）', () {
    test('NotionのURLは「Notionを開く」', () {
      expect(linkOpenLabel('https://www.notion.so/abc'), 'Notionを開く');
      expect(linkOpenLabel('https://notion.so/abc'), 'Notionを開く');
      expect(linkOpenLabel('https://example.notion.site/abc'), 'Notionを開く');
    });

    test('それ以外は「リンクを開く」', () {
      expect(linkOpenLabel('https://digitalhack-note.com/post'), 'リンクを開く');
      expect(linkOpenLabel('https://notnotion.so.example.com/'), 'リンクを開く');
    });
  });

  group('Book.linkUrl（保存と読み込み）', () {
    final now = DateTime(2026, 10, 12);

    test('保存した関連リンクを読み戻せる', () {
      final book = Book(
        id: 'b1', title: 'テスト', createdAt: now, updatedAt: now,
        linkUrl: 'https://www.notion.so/abc');
      final restored = Book.fromMap('b1', book.toMap());
      expect(restored.linkUrl, 'https://www.notion.so/abc');
    });

    test('リンク欄がない既存の本は未登録（null）として読める', () {
      final map = Book(id: 'b2', title: '既存の本', createdAt: now, updatedAt: now)
          .toMap()
        ..remove('linkUrl');
      expect(Book.fromMap('b2', map).linkUrl, isNull);
    });

    test('copyWith でほかの項目を変えてもリンクは残る', () {
      final book = Book(
        id: 'b3', title: 'テスト', createdAt: now, updatedAt: now,
        linkUrl: 'https://example.com/note');
      expect(book.copyWith(status: 'done').linkUrl, 'https://example.com/note');
    });
  });
}
