import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String emoji;
  final int sortOrder;
  final bool isBuiltin;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.emoji = '📁',
    this.sortOrder = 0,
    this.isBuiltin = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'emoji': emoji,
    'sortOrder': sortOrder,
    'isBuiltin': isBuiltin,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
    id: id,
    name: map['name'] ?? '',
    emoji: map['emoji'] ?? '📁',
    sortOrder: map['sortOrder'] ?? 0,
    isBuiltin: map['isBuiltin'] ?? false,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Category copyWith({
    String? name,
    String? emoji,
    int? sortOrder,
  }) => Category(
    id: id,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    sortOrder: sortOrder ?? this.sortOrder,
    isBuiltin: isBuiltin,
    createdAt: createdAt,
  );
}
