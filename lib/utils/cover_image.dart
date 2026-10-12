import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// 自分で撮った（選んだ）写真の表紙かどうか。
/// 写真の表紙は、小さく縮めた画像そのものを文字に変えて
/// （data:image/jpeg;base64,... の形）本のデータの中に保存している。
bool isPhotoCover(String url) => url.startsWith('data:image/');

/// 写真（画像データ）を、本のデータに保存できる文字の形に変える。
String photoCoverDataUrl(Uint8List bytes) {
  final isPng = bytes.length > 3 &&
      bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
  final mime = isPng ? 'image/png' : 'image/jpeg';
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

// 文字→画像データの変換結果を覚えておく（一覧をスクロールするたびに変換し直さないため）
final Map<String, Uint8List> _photoCache = {};

/// 写真の表紙（文字の形）を画像データに戻す。壊れていたら null。
Uint8List? decodePhotoCover(String url) {
  final cached = _photoCache[url];
  if (cached != null) return cached;
  final comma = url.indexOf(',');
  if (comma < 0) return null;
  try {
    final bytes = base64Decode(url.substring(comma + 1));
    if (_photoCache.length >= 80) _photoCache.remove(_photoCache.keys.first);
    _photoCache[url] = bytes;
    return bytes;
  } catch (_) {
    return null;
  }
}

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

/// 表紙表示用ウィジェット。
/// - 写真の表紙：保存してある画像をそのまま表示
/// - URLの表紙：高画質版→取得失敗時は元URL→それも失敗ならplaceholderの順で表示
///   （表示サイズはそのまま、画質だけ引き上げる）
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
    if (isPhotoCover(url)) {
      final bytes = decodePhotoCover(url);
      if (bytes == null) return placeholderBuilder(context);
      return Image.memory(
        bytes,
        fit: fit,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => placeholderBuilder(context),
      );
    }
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
