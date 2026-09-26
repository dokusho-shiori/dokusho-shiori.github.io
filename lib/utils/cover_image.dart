import 'package:flutter/material.dart';

/// 表紙URLを高画質版に変換する（1か所に集約）。
/// Firestoreに保存されているURLそのものは書き換えず、表示時にのみ変換する。
/// - Google Books: zoom を大きく、edge=curl を除去
/// - Amazon: _SL160_ / _SX_ / _SY_ / _SS_ などのサイズトークンを大きく
/// - 楽天: _ex=幅x高さ を大きく
/// - openBD 等、サイズ指定のないURLはそのまま返す
String hiResCoverUrl(String url) {
  if (url.contains('books.google.')) {
    return url
        .replaceAll(RegExp(r'zoom=\d+'), 'zoom=3')
        .replaceAll(RegExp(r'[&?]edge=curl'), '');
  }

  if (url.contains('amazon.com') || url.contains('media-amazon')) {
    return url.replaceAllMapped(
      RegExp(r'_(SL|SX|SY|SS)\d+_'),
      (m) => '_${m[1]}800_',
    );
  }

  if (url.contains('rakuten.co.jp')) {
    return url.replaceAllMapped(
      RegExp(r'_ex=\d+x\d+'),
      (_) => '_ex=600x600',
    );
  }

  return url;
}

/// 表紙表示用ウィジェット。高画質版→取得失敗時は元URL→それも失敗ならplaceholderの順で表示。
/// 表示サイズはそのまま、画質だけ引き上げる。
class CoverNetworkImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext context) placeholderBuilder;

  const CoverNetworkImage({
    super.key,
    required this.url,
    required this.placeholderBuilder,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hiRes = hiResCoverUrl(url);
    return Image.network(
      hiRes,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        if (hiRes == url) return placeholderBuilder(context);
        return Image.network(
          url,
          fit: fit,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) => placeholderBuilder(context),
        );
      },
    );
  }
}
