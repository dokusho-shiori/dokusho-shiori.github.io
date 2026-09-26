import 'package:flutter/material.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class CategoryManageScreen extends StatefulWidget {
  const CategoryManageScreen({super.key});

  @override
  State<CategoryManageScreen> createState() => _CategoryManageScreenState();
}

class _CategoryManageScreenState extends State<CategoryManageScreen> {
  final _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _service.initDefaultCategories();
  }

  Future<void> _showEditDialog({Category? existing}) async {
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          existing == null ? '本の種類を追加' : '本の種類を編集',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Row(
          children: [
            SizedBox(
              width: 54,
              child: TextField(
                controller: emojiCtrl,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 22),
                decoration: InputDecoration(
                  hintText: '📁',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                maxLength: 2,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: '本の種類名',
                  hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w300),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: AppTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                maxLength: 20,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存',
                style: TextStyle(
                    color: AppTheme.gold, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final emoji = emojiCtrl.text.trim().isEmpty ? '📁' : emojiCtrl.text.trim();

    if (existing == null) {
      await _service.addCategory(Category(
        id: '',
        name: name,
        emoji: emoji,
        createdAt: DateTime.now(),
      ));
    } else {
      await _service.updateCategory(existing.copyWith(name: name, emoji: emoji));
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('本の種類を削除',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '「${category.emoji} ${category.name}」を削除しますか？\nこの本の種類に紐付けられた本の種類は未設定になります。',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.headerBg,
        title: const Text(
          '🗂️ 本の種類を管理',
          style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<List<Category>>(
        stream: _service.categoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.gold),
            );
          }
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(
              child: Text('本の種類がありません',
                  style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Center(
                  child: Text(
                    '長押しでドラッグ＆ドロップ並び替え。',
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary, height: 1.6),
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final updated = List<Category>.from(categories);
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    await _service.updateCategorySortOrders(updated);
                  },
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return _CategoryItem(
                      key: ValueKey(cat.id),
                      category: cat,
                      onEdit: () => _showEditDialog(existing: cat),
                      onDelete:
                          cat.isBuiltin ? null : () => _confirmDelete(cat),
                    );
                  },
                ),
              ),
            ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        backgroundColor: AppTheme.gold,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryItem({
    super.key,
    required this.category,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
          ),
          child: Center(
            child: Text(category.emoji,
                style: const TextStyle(fontSize: 22)),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (category.isBuiltin)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4C9B0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '組み込み',
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 編集ボタン
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('編集',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ),
            const SizedBox(width: 6),
            // 削除ボタン or ロックアイコン
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('削除',
                      style: TextStyle(
                          fontSize: 12, color: Colors.red.shade400)),
                ),
              )
            else
              const Icon(Icons.lock_outline,
                  size: 18, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            // ドラッグハンドル
            const Icon(Icons.drag_handle,
                color: AppTheme.textSecondary, size: 22),
          ],
        ),
      ),
    );
  }
}
