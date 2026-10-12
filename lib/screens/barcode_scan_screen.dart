import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../utils/isbn_utils.dart';
import '../widgets/screen_app_bar.dart';

/// 本の裏のバーコード（ISBN）をカメラで読む画面。
/// ISBN（978 / 979 で始まる13桁）が読めたら、その番号を返して閉じる。
/// 下の段のバーコード（値段の番号）は無視する。
class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  // 本のバーコード（EAN-13）だけを読む
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
  );
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done || !mounted) return;
    for (final barcode in capture.barcodes) {
      final isbn = isbn13FromScan(barcode.rawValue);
      if (isbn != null) {
        _done = true;
        Navigator.pop(context, isbn);
        return;
      }
    }
  }

  String _errorMessage(MobileScannerException error) {
    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      return 'カメラの使用が許可されていません。\nブラウザ（または端末）の設定で、このサイトのカメラを許可してください。';
    }
    if (error.errorCode == MobileScannerErrorCode.unsupported) {
      return 'この端末・ブラウザではカメラでの読み取りが使えません。\nISBNを手で入力してください。';
    }
    return 'カメラを使えませんでした。\nISBNを手で入力してください。';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: buildScreenAppBar(context, title: 'バーコードを読む', closeButton: true),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(_errorMessage(error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.6)),
                  ),
                ),
                // バーコードを合わせる目安の枠
                IgnorePointer(
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.8,
                      child: Container(
                        height: 110,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.goldLight, width: 2.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: AppTheme.cardBg,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: const Text(
              '本の裏の、上の段のバーコード（978 か 979 で始まるほう）を枠に合わせてください。\n読めると自動で登録画面に戻ります。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, color: AppTheme.textPrimary, height: 1.6)),
          ),
        ],
      ),
    );
  }
}
