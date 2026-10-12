import 'dart:html' as html;

/// アプリの中身が表示できる状態になったことを index.html に知らせる。
/// 受け取った側が、起動時のロゴをフェードで消す。
void notifyAppReady() {
  html.window.dispatchEvent(html.Event('shiori-app-ready'));
}
