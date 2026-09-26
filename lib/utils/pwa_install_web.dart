import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool get isPwaInstallAvailable =>
    js_util.getProperty(html.window, '_deferredInstallPrompt') != null;

Future<bool> triggerPwaInstall() async {
  final prompt = js_util.getProperty(html.window, '_deferredInstallPrompt');
  if (prompt == null) return false;
  js_util.callMethod(prompt, 'prompt', []);
  final userChoice = await js_util.promiseToFuture<Object>(
    js_util.getProperty(prompt, 'userChoice'),
  );
  js_util.setProperty(html.window, '_deferredInstallPrompt', null);
  return js_util.getProperty(userChoice, 'outcome') == 'accepted';
}
