class Act {
  const Act({
    this.id,
    required this.projectId,
    required this.title,
    required this.sequenceOrder,
  });

  final int? id;
  final int projectId;
  final String title;
  final int sequenceOrder;

  factory Act.fromMap(Map<String, Object?> map) {
    return Act(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      title: map['title'] as String,
      sequenceOrder: map['sequence_order'] as int,
    );
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'project_id': projectId,
      'title': title,
      'sequence_order': sequenceOrder,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  Act copyWith({int? id, int? projectId, String? title, int? sequenceOrder}) {
    return Act(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    );
  }
}
