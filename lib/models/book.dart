import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String publisher;
  final String? thumbnail;
  final String? isbn;
  final String? asin;
  final String status;
  final int currentPage;
  final int totalPages;
  final int price;
  final List<String> tags;
  final String? memo;
  final String? buyDate;
  final String? startDate;
  final String? endDate;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? purchaseLocation;
  final String? categoryId;
  final String? notionPageId;

  Book({
    required this.id,
    required this.title,
    this.author = '',
    this.publisher = '',
    this.thumbnail,
    this.isbn,
    this.asin,
    this.status = 'wish',
    this.currentPage = 0,
    this.totalPages = 0,
    this.price = 0,
    this.tags = const [],
    this.memo,
    this.buyDate,
    this.startDate,
    this.endDate,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.purchaseLocation,
    this.categoryId,
    this.notionPageId,
  });

  double get progress {
    if (totalPages == 0) return 0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'author': author,
    'publisher': publisher,
    'thumbnail': thumbnail,
    'isbn': isbn,
    'asin': asin,
    'status': status,
    'currentPage': currentPage,
    'totalPages': totalPages,
    'price': price,
    'tags': tags,
    'memo': memo,
    'buyDate': buyDate,
    'startDate': startDate,
    'endDate': endDate,
    'sortOrder': sortOrder,
    'purchaseLocation': purchaseLocation,
    'categoryId': categoryId,
    'notionPageId': notionPageId,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Book.fromMap(String id, Map<String, dynamic> map) => Book(
    id: id,
    title: map['title'] ?? '',
    author: map['author'] ?? '',
    publisher: map['publisher'] ?? '',
    thumbnail: map['thumbnail'],
    isbn: map['isbn'],
    asin: map['asin'],
    status: map['status'] ?? 'wish',
    currentPage: map['currentPage'] ?? 0,
    totalPages: map['totalPages'] ?? 0,
    price: map['price'] ?? 0,
    tags: List<String>.from(map['tags'] ?? []),
    memo: map['memo'],
    buyDate: map['buyDate'],
    startDate: map['startDate'],
    endDate: map['endDate'],
    sortOrder: map['sortOrder'] ?? 0,
    purchaseLocation: map['purchaseLocation'],
    categoryId: map['categoryId'],
    notionPageId: map['notionPageId'],
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? publisher,
    String? thumbnail,
    String? isbn,
    String? asin,
    String? status,
    int? currentPage,
    int? totalPages,
    int? price,
    List<String>? tags,
    String? memo,
    String? buyDate,
    String? startDate,
    String? endDate,
    int? sortOrder,
    String? purchaseLocation,
    String? categoryId,
    String? notionPageId,
  }) => Book(
    id: id ?? this.id,
    title: title ?? this.title,
    author: author ?? this.author,
    publisher: publisher ?? this.publisher,
    thumbnail: thumbnail ?? this.thumbnail,
    isbn: isbn ?? this.isbn,
    asin: asin ?? this.asin,
    status: status ?? this.status,
    currentPage: currentPage ?? this.currentPage,
    totalPages: totalPages ?? this.totalPages,
    price: price ?? this.price,
    tags: tags ?? this.tags,
    memo: memo ?? this.memo,
    buyDate: buyDate ?? this.buyDate,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    sortOrder: sortOrder ?? this.sortOrder,
    purchaseLocation: purchaseLocation ?? this.purchaseLocation,
    categoryId: categoryId ?? this.categoryId,
    notionPageId: notionPageId ?? this.notionPageId,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}
