import '../models/cinex_models.dart';

class ScheduleDraftScene {
  ScheduleDraftScene({
    required this.scene,
    required this.sequenceOrder,
    this.plannedStartTime,
    this.plannedEndTime,
  });

  final Scene scene;
  final int sequenceOrder;
  final String? plannedStartTime;
  final String? plannedEndTime;
}

class ScheduleDraftDay {
  ScheduleDraftDay({
    required this.date,
    required this.title,
    required this.maxMinutes,
    required this.scenes,
  });

  final DateTime date;
  final String title;
  final int maxMinutes;
  final List<ScheduleDraftScene> scenes;

  int get totalMinutes => scenes.fold(
        0,
        (sum, item) => sum + item.scene.estimatedDurationMinutes,
      );
}

class SchedulePlanResult {
  SchedulePlanResult({required this.days, required this.warnings});

  final List<ScheduleDraftDay> days;
  final List<String> warnings;
}

class ProductionScheduleOptimizer {
  const ProductionScheduleOptimizer();

  SchedulePlanResult generate({
    required Project project,
    required List<Scene> readyScenes,
    required DateTime startDate,
  }) {
    final warnings = <String>[];
    final candidates = <Scene>[];

    for (final scene in readyScenes) {
      if (scene.productionStatus == 'CANCELLED' ||
          scene.productionStatus == 'NOT_READY') {
        continue;
      }
      if (scene.plannedShootingLocationId == null) {
        warnings
            .add('Cảnh ${scene.sceneNumber} chưa có địa điểm quay.');
        continue;
      }
      if (scene.estimatedDurationMinutes > project.maxShootingMinutesPerDay) {
        warnings.add(
          'Cảnh ${scene.sceneNumber} vượt quá thời lượng tối đa mỗi ngày.',
        );
        continue;
      }
      final resourceIssue = scene.resources.where(
        (resource) => resource.requiredQuantity > resource.quantityTotal,
      );
      if (resourceIssue.isNotEmpty) {
        warnings.add('Cảnh ${scene.sceneNumber} không đủ tài nguyên.');
        continue;
      }
      candidates.add(scene);
    }

    candidates.sort(_stableSceneSort);

    final days = <ScheduleDraftDay>[];
    var remaining = List<Scene>.of(candidates);
    var date = DateTime(startDate.year, startDate.month, startDate.day);

    while (remaining.isNotEmpty) {
      final picked = <Scene>[];
      final resourceUsage = <int, int>{};
      var minutes = 0;
      var seed = remaining.removeAt(0);
      picked.add(seed);
      minutes += seed.estimatedDurationMinutes;
      _addResourceUsage(seed, resourceUsage);

      while (remaining.isNotEmpty) {
        final scored = remaining
            .map((scene) => MapEntry(scene, _score(seed, scene)))
            .toList()
          ..sort((a, b) {
            final scoreCompare = b.value.compareTo(a.value);
            if (scoreCompare != 0) return scoreCompare;
            return _stableSceneSort(a.key, b.key);
          });
        Scene? next;
        for (final entry in scored) {
          final scene = entry.key;
          if (minutes + scene.estimatedDurationMinutes <=
                  project.maxShootingMinutesPerDay &&
              _resourcesFit(scene, resourceUsage)) {
            next = scene;
            break;
          }
        }
        if (next == null) break;
        remaining.remove(next);
        picked.add(next);
        minutes += next.estimatedDurationMinutes;
        _addResourceUsage(next, resourceUsage);
        seed = next;
      }

      days.add(
        ScheduleDraftDay(
          date: date,
          title: 'Lịch gợi ý ${days.length + 1}',
          maxMinutes: project.maxShootingMinutesPerDay,
          scenes: [
            for (var index = 0; index < picked.length; index++)
              ScheduleDraftScene(
                scene: picked[index],
                sequenceOrder: index + 1,
                plannedStartTime: _clockForOffset(
                  picked.take(index).fold<int>(
                        8 * 60,
                        (sum, scene) => sum + scene.estimatedDurationMinutes,
                      ),
                ),
                plannedEndTime: _clockForOffset(
                  picked.take(index + 1).fold<int>(
                        8 * 60,
                        (sum, scene) => sum + scene.estimatedDurationMinutes,
                      ),
                ),
              ),
          ],
        ),
      );
      date = date.add(const Duration(days: 1));
    }

    if (days.isEmpty && candidates.isEmpty) {
      warnings.add('Không có cảnh nào có thể xếp lịch với các ràng buộc hiện tại.');
    }

    return SchedulePlanResult(days: days, warnings: warnings);
  }

  int _score(Scene anchor, Scene candidate) {
    var score = 0;
    if (anchor.plannedShootingLocationId ==
        candidate.plannedShootingLocationId) {
      score += 100;
    } else {
      score -= 50;
    }
    if (anchor.timeOfDay == candidate.timeOfDay) score += 30;
    final anchorCharacters = anchor.characters.map((item) => item.id).toSet();
    final candidateCharacters =
        candidate.characters.map((item) => item.id).toSet();
    score += anchorCharacters.intersection(candidateCharacters).length * 20;
    final anchorResources = anchor.resources.map((item) => item.id).toSet();
    final candidateResources =
        candidate.resources.map((item) => item.id).toSet();
    score += anchorResources.intersection(candidateResources).length * 10;
    score += (6 - candidate.priority).clamp(0, 5);
    return score;
  }

  bool _resourcesFit(Scene scene, Map<int, int> usage) {
    for (final resource in scene.resources) {
      final next = (usage[resource.id] ?? 0) + resource.requiredQuantity;
      if (next > resource.quantityTotal) return false;
    }
    return true;
  }

  void _addResourceUsage(Scene scene, Map<int, int> usage) {
    for (final resource in scene.resources) {
      usage.update(
        resource.id,
        (value) => value + resource.requiredQuantity,
        ifAbsent: () => resource.requiredQuantity,
      );
    }
  }

  static int _stableSceneSort(Scene a, Scene b) {
    final location = (a.plannedShootingLocationId ?? 0)
        .compareTo(b.plannedShootingLocationId ?? 0);
    if (location != 0) return location;
    final time = a.timeOfDay.compareTo(b.timeOfDay);
    if (time != 0) return time;
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;
    return a.sceneNumber.compareTo(b.sceneNumber);
  }

  String _clockForOffset(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
