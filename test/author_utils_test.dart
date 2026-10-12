import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/utils/author_utils.dart';

void main() {
  group('cleanAuthorName', () {
    test('姓・名・生没年のカンマ区切りから名前だけにする', () {
      expect(cleanAuthorName('村上, 春樹, 1949-'), '村上春樹');
      expect(cleanAuthorName('村上,春樹,1949-'), '村上春樹');
      expect(cleanAuthorName('外山, 滋比古, 1923-2020'), '外山滋比古');
    });

    test('役割（著・訳など）を外す', () {
      expect(cleanAuthorName('外山滋比古／著'), '外山滋比古');
      expect(cleanAuthorName('外山 滋比古／著'), '外山滋比古');
      expect(cleanAuthorName('村上春樹 著'), '村上春樹');
      expect(cleanAuthorName('村上春樹 [著]'), '村上春樹');
    });

    test('名前の最後の字が役割と同じでも、名前は削らない', () {
      expect(cleanAuthorName('伊藤博文'), '伊藤博文');
      expect(cleanAuthorName('遠藤周作'), '遠藤周作');
    });

    test('姓と名の間の空白を取る', () {
      expect(cleanAuthorName('外山 滋比古'), '外山滋比古');
      expect(cleanAuthorName('外山　滋比古'), '外山滋比古');
    });

    test('英字やカタカナの名前は、名・姓の順にする', () {
      expect(cleanAuthorName('Harari, Yuval N., 1976-'), 'Yuval N. Harari');
      expect(cleanAuthorName('ハラリ, ユヴァル・ノア, 1976-'), 'ユヴァル・ノア・ハラリ');
    });

    test('もともときれいな名前はそのまま', () {
      expect(cleanAuthorName('村上春樹'), '村上春樹');
      expect(cleanAuthorName('Yuval Noah Harari'), 'Yuval Noah Harari');
    });

    test('生没年だけなら空にする', () {
      expect(cleanAuthorName('1949-'), '');
      expect(cleanAuthorName(''), '');
    });
  });

  group('joinAuthors', () {
    test('複数人を「・」でつなぐ', () {
      expect(joinAuthors(['Harari, Yuval N., 1976-', '柴田, 裕之, 1959-']),
          'Yuval N. Harari・柴田裕之');
    });

    test('同じ名前は1回だけ', () {
      expect(joinAuthors(['村上, 春樹, 1949-', '村上春樹 著']), '村上春樹');
    });
  });

  group('splitAuthorSummary', () {
    test('役割つきの並びを人ごとに分ける', () {
      expect(splitAuthorSummary('外山滋比古／著 柴田裕之／翻訳'), ['外山滋比古', '柴田裕之']);
    });

    test('空白区切りの並びを人ごとに分ける', () {
      expect(splitAuthorSummary('Harari,YuvalN.,1976- 柴田,裕之,1959-'),
          ['Harari,YuvalN.,1976-', '柴田,裕之,1959-']);
      expect(joinAuthors(splitAuthorSummary('村上,春樹,1949-')), '村上春樹');
    });
  });
}
