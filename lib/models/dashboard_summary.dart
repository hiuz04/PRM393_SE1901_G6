class DashboardSummary {
  const DashboardSummary({
    required this.totalCharacters,
    required this.totalScenes,
    required this.doneScenes,
  });

  final int totalCharacters;
  final int totalScenes;
  final int doneScenes;

  double get progress {
    if (totalScenes == 0) {
      return 0;
    }

    return doneScenes / totalScenes;
  }

  int get progressPercentage => (progress * 100).round();

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      totalCharacters: 0,
      totalScenes: 0,
      doneScenes: 0,
    );
  }

  factory DashboardSummary.fromMap(Map<String, Object?> map) {
    return DashboardSummary(
      totalCharacters: map['totalCharacters'] as int? ?? 0,
      totalScenes: map['totalScenes'] as int? ?? 0,
      doneScenes: map['doneScenes'] as int? ?? 0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'totalCharacters': totalCharacters,
      'totalScenes': totalScenes,
      'doneScenes': doneScenes,
      'progressPercentage': progressPercentage,
    };
  }

  DashboardSummary copyWith({
    int? totalCharacters,
    int? totalScenes,
    int? doneScenes,
  }) {
    return DashboardSummary(
      totalCharacters: totalCharacters ?? this.totalCharacters,
      totalScenes: totalScenes ?? this.totalScenes,
      doneScenes: doneScenes ?? this.doneScenes,
    );
  }
}
