import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/utils/isbn_utils.dart';

void main() {
  group('isIsbn13', () {
    test('978で始まる正しいISBNは通る', () {
      expect(isIsbn13('9784167110123'), isTrue);
      expect(isIsbn13('9784101001555'), isTrue);
    });

    test('下の段のバーコード（192…）はISBNではない', () {
      expect(isIsbn13('1920193007439'), isFalse);
    });

    test('最後の1桁が合わないものは通さない（読み間違い対策）', () {
      expect(isIsbn13('9784167110124'), isFalse);
    });

    test('桁数が違うもの・数字以外は通さない', () {
      expect(isIsbn13('978416711012'), isFalse);
      expect(isIsbn13('97841671101234'), isFalse);
      expect(isIsbn13('978416711012X'), isFalse);
      expect(isIsbn13(''), isFalse);
    });
  });

  group('isbn13FromScan', () {
    test('ハイフンや空白が混ざっていても数字だけ取り出す', () {
      expect(isbn13FromScan('978-4-16-711012-3'), '9784167110123');
      expect(isbn13FromScan(' 9784167110123 '), '9784167110123');
    });

    test('ISBNでなければ null', () {
      expect(isbn13FromScan(null), isNull);
      expect(isbn13FromScan('1920193007439'), isNull);
      expect(isbn13FromScan('hello'), isNull);
    });
  });
}
