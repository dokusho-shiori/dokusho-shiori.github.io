import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotionDeletedDialog extends StatefulWidget {
  final List<Map<String, dynamic>> deletedMemos;
  final Future<void> Function() onKeepInShiori;
  final Future<void> Function() onDeleteFromShiori;
  final Future<void> Function() onRestoreToNotion;

  const NotionDeletedDialog({
    super.key,
    required this.deletedMemos,
    required this.onKeepInShiori,
    required this.onDeleteFromShiori,
    required this.onRestoreToNotion,
  });

  @override
  State<NotionDeletedDialog> createState() => _NotionDeletedDialogState();
}

class _NotionDeletedDialogState extends State<NotionDeletedDialog> {
  bool _isProcessing = false;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _isProcessing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.deletedMemos.length;
    final previews = widget.deletedMemos.take(3).toList();

    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(
        'Notionで$count件のメモが削除されました',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '削除されたメモのプレビュー：',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            ...previews.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    m['content'] as String? ?? '（内容なし）',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            if (count > 3) ...[
              const SizedBox(height: 4),
              Text(
                'ほか ${count - 3} 件',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'どうしますか？',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (_isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.gold),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1, color: AppTheme.border),
              TextButton(
                onPressed: () => _handle(() async {
                  Navigator.of(context).pop();
                  await widget.onKeepInShiori();
                }),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
                child: const Text(
                  '① 栞に残す（Notionだけ削除）',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              TextButton(
                onPressed: () => _handle(() async {
                  Navigator.of(context).pop();
                  await widget.onDeleteFromShiori();
                }),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
                child: const Text(
                  '② 栞からも削除する',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              TextButton(
                onPressed: () => _handle(() async {
                  Navigator.of(context).pop();
                  await widget.onRestoreToNotion();
                }),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
                child: const Text(
                  '③ キャンセル（Notionに復元）',
                  style: TextStyle(color: AppTheme.gold, fontSize: 14),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
