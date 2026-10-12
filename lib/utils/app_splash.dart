// 起動時のロゴ（index.html 側で表示しているもの）を消す合図。
// Webでは実際に合図を送り、それ以外（アプリ版）では何もしない。
export 'app_splash_stub.dart'
    if (dart.library.html) 'app_splash_web.dart';
