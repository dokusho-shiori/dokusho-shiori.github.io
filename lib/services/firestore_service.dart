import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book.dart';
import '../models/category.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _booksRef =>
      _db.collection('users').doc(_uid).collection('books');

  Stream<List<Book>> booksStream() {
    if (_uid == null) return Stream.value([]);
    return _booksRef
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Book.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<String> addBook(Book book) async {
    if (_uid == null) return '';
    // sortOrderを現在の最大値+1に
    final snap = await _booksRef.orderBy('sortOrder', descending: true).limit(1).get();
    final maxOrder = snap.docs.isEmpty ? 0 : (snap.docs.first.data()['sortOrder'] ?? 0) as int;
    final ref = await _booksRef.add(book.copyWith(sortOrder: maxOrder + 1).toMap());
    return ref.id;
  }

  Future<void> updateBook(Book book) async {
    if (_uid == null) return;
    await _booksRef.doc(book.id).update(book.toMap());
  }

  Future<void> deleteBook(String bookId) async {
    if (_uid == null) return;
    await _booksRef.doc(bookId).delete();
  }

  Future<void> swapSortOrder(Book a, Book b) async {
    if (_uid == null) return;
    final batch = _db.batch();
    batch.update(_booksRef.doc(a.id), {'sortOrder': b.sortOrder});
    batch.update(_booksRef.doc(b.id), {'sortOrder': a.sortOrder});
    await batch.commit();
  }

  // ドラッグ&ドロップ後に全件のsortOrderを更新
  Future<void> updateSortOrders(List<Book> books) async {
    if (_uid == null) return;
    final batch = _db.batch();
    for (int i = 0; i < books.length; i++) {
      batch.update(_booksRef.doc(books[i].id), {'sortOrder': i});
    }
    await batch.commit();
  }

  // 購入場所設定
  static const defaultPurchaseLocations = ['Amazon', '楽天ブックス', '紀伊國屋書店', 'BookOff', 'その他'];

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      _db.collection('users').doc(_uid).collection('settings').doc('preferences');

  Future<List<String>> getPurchaseLocations() async {
    if (_uid == null) return defaultPurchaseLocations;
    final doc = await _settingsRef.get();
    if (!doc.exists) return defaultPurchaseLocations;
    final list = doc.data()?['purchaseLocations'] as List?;
    return list?.cast<String>() ?? defaultPurchaseLocations;
  }

  Future<void> savePurchaseLocations(List<String> locations) async {
    if (_uid == null) return;
    await _settingsRef.set({'purchaseLocations': locations}, SetOptions(merge: true));
  }

  // ===== カテゴリ =====
  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _db.collection('users').doc(_uid).collection('categories');

  static const defaultCategories = [
    {'name': '未分類', 'emoji': '📁', 'isBuiltin': true},
    {'name': '小説', 'emoji': '📖', 'isBuiltin': true},
    {'name': 'ビジネス', 'emoji': '💼', 'isBuiltin': true},
    {'name': '技術書', 'emoji': '💻', 'isBuiltin': true},
  ];

  /// 初回のみデフォルトカテゴリを作成する
  Future<void> initDefaultCategories() async {
    if (_uid == null) return;
    final snap = await _categoriesRef.limit(1).get();
    if (snap.docs.isNotEmpty) return; // 既に存在する場合はスキップ
    final batch = _db.batch();
    for (int i = 0; i < defaultCategories.length; i++) {
      final ref = _categoriesRef.doc();
      batch.set(ref, {
        'name': defaultCategories[i]['name'],
        'emoji': defaultCategories[i]['emoji'],
        'isBuiltin': defaultCategories[i]['isBuiltin'],
        'sortOrder': i,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  Stream<List<Category>> categoriesStream() {
    if (_uid == null) return Stream.value([]);
    return _categoriesRef
        .orderBy('sortOrder')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Category.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addCategory(Category category) async {
    if (_uid == null) return;
    final snap = await _categoriesRef.orderBy('sortOrder', descending: true).limit(1).get();
    final maxOrder = snap.docs.isEmpty
        ? 0
        : (snap.docs.first.data()['sortOrder'] ?? 0) as int;
    await _categoriesRef.add(category.copyWith(sortOrder: maxOrder + 1).toMap());
  }

  Future<void> updateCategory(Category category) async {
    if (_uid == null) return;
    await _categoriesRef.doc(category.id).update({
      'name': category.name,
      'emoji': category.emoji,
    });
  }

  Future<void> deleteCategory(String categoryId) async {
    if (_uid == null) return;
    await _categoriesRef.doc(categoryId).delete();
  }

  Future<void> updateCategorySortOrders(List<Category> categories) async {
    if (_uid == null) return;
    final batch = _db.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update(_categoriesRef.doc(categories[i].id), {'sortOrder': i});
    }
    await batch.commit();
  }
}
