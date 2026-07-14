class Project {
  const Project({
    this.id,
    required this.title,
    this.genre,
    this.description,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String? genre;
  final String? description;
  final String createdAt;

  factory Project.fromMap(Map<String, Object?> map) {
    return Project(
      id: map['id'] as int?,
      title: map['title'] as String,
      genre: map['genre'] as String?,
      description: map['description'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'title': title,
      'genre': genre,
      'description': description,
      'created_at': createdAt,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  Project copyWith({
    int? id,
    String? title,
    String? genre,
    String? description,
    String? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
