/// バーコードなどで読んだ数字が、本のISBN（13桁）かどうかを判定する。
///
/// 日本の本の裏にはバーコードが2段ある。
///   上の段：978 / 979 で始まる13桁 … これが ISBN
///   下の段：192 で始まる13桁 … 分類と値段の番号（ISBNではない）
/// ここでは上の段だけを ISBN として認める。
/// 読み間違いを拾わないよう、最後の1桁（検査用の数字）が合っているかも確かめる。
bool isIsbn13(String value) {
  if (!RegExp(r'^97[89]\d{10}$').hasMatch(value)) return false;
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(value[i]) * (i.isEven ? 1 : 3);
  }
  final check = (10 - (sum % 10)) % 10;
  return check == int.parse(value[12]);
}

/// 読み取った文字から数字だけを取り出し、ISBN（13桁）ならそれを返す。違えば null。
String? isbn13FromScan(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  return isIsbn13(digits) ? digits : null;
}
