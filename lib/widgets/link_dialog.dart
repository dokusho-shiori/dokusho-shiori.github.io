import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/link_utils.dart';

/// 関連リンク（NotionなどのURL）を入力する小さなダイアログ。
/// 保存されたら整えたURLを返す。キャンセルしたら null を返す。
Future<String?> showLinkInputDialog(BuildContext context, {String? initial}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _LinkInputDialog(initial: initial),
  );
}

class _LinkInputDialog extends StatefulWidget {
  final String? initial;
  const _LinkInputDialog({this.initial});

  @override
  State<_LinkInputDialog> createState() => _LinkInputDialogState();
}

class _LinkInputDialogState extends State<_LinkInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = normalizeLinkUrl(_controller.text);
    if (url == null) {
      setState(() => _error = 'https:// で始まるURLを入力してください');
      return;
    }
    Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('関連リンクを追加',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NotionのページやブログなどのURLを貼り付けてください',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'https://www.notion.so/...',
                hintStyle: const TextStyle(
                  color: AppTheme.textSecondary, fontWeight: FontWeight.w300),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル')),
        TextButton(
          onPressed: _submit,
          child: const Text('保存')),
      ],
    );
  }
}
