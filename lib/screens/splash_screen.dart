import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_splash.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

const Color _splashBg = Color(0xFFF6F0E4);
const String _logoAsset = 'assets/images/shiori_logo.png';

/// ロゴをフェード（ディゾルブ）でふわっと表示する画面。
/// 画像の読み込みが終わってからフェードを始めるので、途中でパッと出ることがない。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: Center(
        child: Image.asset(
          _logoAsset,
          width: 168, height: 168,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            // 画像が用意できたら、次の描画からフェードを始める
            if (frame != null && !_visible) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !_visible) setState(() => _visible = true);
              });
            }
            return AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeInOut,
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// ログイン状態に合わせて「ロゴ → ホーム／ログイン画面」を切り替える入口。
///
/// - 起動直後（Web）：ロゴは index.html 側が表示している。ここでは重ねて出さず、
///   中身の準備ができたら合図を送って、HTML側のロゴをふわっと消してもらう。
/// - 起動直後（アプリ版）：[SplashScreen] をふわっと出してから中身へ切り替える。
/// - ログイン／ログアウトしたとき：[SplashScreen] をふわっと出してから切り替える。
///
/// 画面の切り替えはすべてフェード（ディゾルブ）で行う。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // ロゴを見せておく時間（フェードで出きって、少し止まるまで）
  static const _splashHold = Duration(milliseconds: 1300);

  StreamSubscription<User?>? _sub;
  Timer? _timer;

  /// ログイン中かどうか。null は「まだ分からない（起動直後）」。
  bool? _loggedIn;
  bool _showSplash = true;
  int _splashRun = 0;
  bool _logoPrecached = false;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) {
      _loggedIn = true;
      if (kIsWeb) _showSplash = false;
      _afterStartupResolved();
    }
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ログイン直後のロゴがすぐ出せるよう、画像を先に読み込んでおく
    if (!_logoPrecached) {
      _logoPrecached = true;
      precacheImage(const AssetImage(_logoAsset), context);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _onAuthChanged(User? user) {
    if (!mounted) return;
    final loggedIn = user != null;

    // 起動後、はじめてログイン状態が分かったとき
    if (_loggedIn == null) {
      setState(() {
        _loggedIn = loggedIn;
        if (kIsWeb) _showSplash = false;
      });
      _afterStartupResolved();
      return;
    }

    // 変化なし（内部的な更新など）は何もしない
    if (loggedIn == _loggedIn) return;

    // ログイン／ログアウトで状態が変わった → ロゴをふわっと出してから切り替える
    _timer?.cancel();
    setState(() {
      _loggedIn = loggedIn;
      _showSplash = true;
      _splashRun++;
    });
    _timer = Timer(_splashHold, () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  /// 起動時のログイン状態が分かったあとの処理。
  void _afterStartupResolved() {
    if (kIsWeb) {
      // 中身を1回描いてから、HTML側のロゴを消す合図を送る
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyAppReady());
    } else {
      _timer?.cancel();
      _timer = Timer(_splashHold, () {
        if (mounted) setState(() => _showSplash = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_loggedIn == null && kIsWeb) {
      // Web起動直後：ロゴはHTML側が表示中。下は同じ色の無地にしておく
      child = const ColoredBox(
        key: ValueKey('blank'),
        color: _splashBg,
        child: SizedBox.expand(),
      );
    } else if (_showSplash || _loggedIn == null) {
      child = SplashScreen(key: ValueKey('splash$_splashRun'));
    } else if (_loggedIn == true) {
      child = const HomeScreen(key: ValueKey('home'));
    } else {
      child = const WelcomeScreen(key: ValueKey('welcome'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: child,
    );
  }
}
