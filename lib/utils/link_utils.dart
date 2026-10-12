/// 本に付ける「関連リンク」（NotionなどのURL）まわりの共通処理。

/// 入力されたURLを整える。
/// http:// か https:// で始まる正しいURLだけを通し、それ以外は null を返す。
/// （javascript: などの危険な形式を保存・実行させないため）
String? normalizeLinkUrl(String? input) {
  final text = (input ?? '').trim();
  if (text.isEmpty) return null;
  if (RegExp(r'\s').hasMatch(text)) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return text;
}

/// リンクを開くボタンの表示名。NotionのURLなら「Notionを開く」にする。
String linkOpenLabel(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  final isNotion = host == 'notion.so' || host.endsWith('.notion.so') ||
      host == 'notion.site' || host.endsWith('.notion.site') ||
      host == 'notion.com' || host.endsWith('.notion.com');
  return isNotion ? 'Notionを開く' : 'リンクを開く';
}
