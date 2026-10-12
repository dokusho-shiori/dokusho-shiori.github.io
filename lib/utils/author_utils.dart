/// 著者名の整形。
///
/// 本の情報の取得元によって、著者名は次のような形で返ってくる。
///   「村上, 春樹, 1949-」「村上,春樹,1949-」 … 姓・名・生没年のカンマ区切り
///   「外山滋比古／著」「村上春樹 [著]」      … 役割（著・訳など）つき
///   「外山 滋比古」                          … 姓と名の間に空白
/// これらを「村上春樹」のような、名前だけの形にそろえる。

// 「1949-」「1867-1916」などの生没年
final RegExp _years = RegExp(r'^[\d?？]{3,4}\s*[-‐–—~〜]\s*[\d?？]{0,4}$');
final RegExp _yearsAtEnd = RegExp(r'[\s　]*\d{3,4}\s*[-‐–—~〜]\s*\d{0,4}$');

// 名前の後ろに付く役割。「伊藤博文」「遠藤周作」のように名前の最後の字と
// 同じ場合があるので、前に空白があるか、かっこで囲まれているときだけ外す。
const String _roles = '著|作|編|訳|翻訳|監修|監訳|編著|共著|原作|文|絵|写真|イラスト|解説|編集';
final RegExp _roleAfterSpace = RegExp('[\\s　]+($_roles)\$');
final RegExp _roleInBrackets = RegExp('[\\s　]*[\\[［(（〔]($_roles)[\\]］)）〕]\$');

final RegExp _latinOnly = RegExp(r'^[ -~À-ɏ]+$');
final RegExp _katakanaOnly = RegExp(r'^[゠-ヿ\s　]+$');
final RegExp _spaces = RegExp(r'[\s　]+');

/// 1人分の著者名から、カンマ・生没年・役割などを取り除く。
String cleanAuthorName(String raw) {
  var s = raw.trim();

  // 「外山滋比古／著」→「外山滋比古」
  final slash = s.indexOf(RegExp(r'[／/]'));
  if (slash >= 0) s = s.substring(0, slash).trim();

  // 「村上春樹 著」「村上春樹 [著]」→「村上春樹」
  s = s.replaceFirst(_roleInBrackets, '').replaceFirst(_roleAfterSpace, '').trim();

  // カンマで分けて、生没年を捨てる
  final parts = s
      .split(RegExp(r'[,，]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty && !_years.hasMatch(p))
      .toList();
  if (parts.isEmpty) return '';

  String name;
  if (parts.length == 1) {
    name = parts.first;
  } else {
    // 「姓, 名」の形
    final family = parts.first;
    final given = parts.sublist(1).join(' ');
    if (_latinOnly.hasMatch(family) && _latinOnly.hasMatch(given)) {
      name = '$given $family'; // Harari, Yuval N. → Yuval N. Harari
    } else if (_katakanaOnly.hasMatch(family) && _katakanaOnly.hasMatch(given)) {
      name = '$given・$family'; // ハラリ, ユヴァル・ノア → ユヴァル・ノア・ハラリ
    } else {
      name = '$family$given'; // 村上, 春樹 → 村上春樹
    }
  }

  // 名前の後ろに残った生没年を落とす
  name = name.replaceFirst(_yearsAtEnd, '').trim();

  if (_latinOnly.hasMatch(name)) return name.replaceAll(_spaces, ' ');
  if (_katakanaOnly.hasMatch(name)) return name.replaceAll(_spaces, '・');
  return name.replaceAll(_spaces, ''); // 外山 滋比古 → 外山滋比古
}

/// 何人かの著者名をそれぞれ整えて「・」でつなぐ。同じ名前は1回だけにする。
String joinAuthors(Iterable<String> rawNames) {
  final seen = <String>{};
  final names = <String>[];
  for (final raw in rawNames) {
    final name = cleanAuthorName(raw);
    if (name.isNotEmpty && seen.add(name)) names.add(name);
  }
  return names.join('・');
}

/// 著者が1本の文字列にまとまっているもの（例：「外山滋比古／著 柴田裕之／翻訳」
/// 「Harari,YuvalN.,1976- 柴田,裕之,1959-」）を、人ごとに分ける。
List<String> splitAuthorSummary(String summary) {
  final s = summary.trim();
  if (s.isEmpty) return [];
  if (s.contains('／') || s.contains('/')) {
    return RegExp(r'([^／/]+)[／/]\S*')
        .allMatches(s)
        .map((m) => m.group(1)!.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return s.split(_spaces).where((e) => e.isNotEmpty).toList();
}
