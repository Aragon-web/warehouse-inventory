class Warehouse {
  final int id;
  final String name;
  final String slug;
  final String createdAt;

  const Warehouse({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  factory Warehouse.fromMap(Map<String, dynamic> map) {
    return Warehouse(
      id: map['id'] as int,
      name: map['name'] as String,
      slug: map['slug'] as String,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'created_at': createdAt,
    };
  }
}
