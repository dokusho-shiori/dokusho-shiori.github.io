import 'package:flutter/material.dart';

const Color _splashBg = Color(0xFFF6F0E4);

/// 起動時・Googleログイン直後に表示するスプラッシュ（ロゴがフェード＋下から上へ浮かび上がる）。
/// [onDone] を渡すと、アニメーション終了後に一度だけ呼ばれる。
class SplashScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const SplashScreen({super.key, this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final onDone = widget.onDone;
    if (onDone != null) {
      Future.delayed(const Duration(milliseconds: 950), () {
        if (mounted) onDone();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Image.asset(
              'assets/images/shiori_logo.png',
              width: 168, height: 168,
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] を表示する前に一度だけ[SplashScreen]を挟むゲート。
/// keyを変えて再生成すると再びスプラッシュを再生する（＝ログイン状態が変わった時に使う）。
class SplashGate extends StatefulWidget {
  final Widget child;
  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return SplashScreen(onDone: () {
      if (mounted) setState(() => _done = true);
    });
  }
}
