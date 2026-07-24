import '../models/cinex_models.dart';

enum ScheduleConflictSeverity { warning, blocking }

class ScheduleConflict {
  ScheduleConflict({
    required this.message,
    required this.severity,
    this.sceneId,
    this.shootingDayId,
  });

  final String message;
  final ScheduleConflictSeverity severity;
  final int? sceneId;
  final int? shootingDayId;

  bool get blocking => severity == ScheduleConflictSeverity.blocking;
}

class ScheduleConflictService {
  const ScheduleConflictService();

  List<ScheduleConflict> detect({
    required List<ShootingDay> shootingDays,
    required Map<int, Scene> scenesById,
    bool userCanConfirm = true,
    bool editingCompletedDay = false,
  }) {
    final conflicts = <ScheduleConflict>[];
    final sceneAssignments = <int, int>{};

    for (final day in shootingDays) {
      if (day.totalMinutes > day.maxMinutes) {
        conflicts.add(
          ScheduleConflict(
            shootingDayId: day.id,
            severity: ScheduleConflictSeverity.blocking,
            message:
                '${day.title} vượt quá giới hạn trong ngày (${day.totalMinutes}/${day.maxMinutes} phút).',
          ),
        );
      }

      final ranges = <_TimeRange>[];
      final resourceUsage = <int, int>{};
      final resourcesById = <int, SceneResource>{};
      for (final item in day.scenes) {
        final scene = item.scene;
        final previousDayId = sceneAssignments[scene.id];
        if (previousDayId != null && day.isActive) {
          conflicts.add(
            ScheduleConflict(
              sceneId: scene.id,
              shootingDayId: day.id,
              severity: ScheduleConflictSeverity.blocking,
              message:
                  'Cảnh ${scene.sceneNumber} đang được xếp vào nhiều ngày quay còn hiệu lực.',
            ),
          );
        } else if (day.isActive) {
          sceneAssignments[scene.id] = day.id;
        }

        if (scene.plannedShootingLocationId == null) {
          conflicts.add(
            ScheduleConflict(
              sceneId: scene.id,
              shootingDayId: day.id,
              severity: ScheduleConflictSeverity.blocking,
              message:
                  'Cảnh ${scene.sceneNumber} chưa có địa điểm quay.',
            ),
          );
        }

        if (scene.settingType == 'INT' &&
            !scene.shootingLocationSupportsInterior) {
          conflicts.add(
            ScheduleConflict(
              sceneId: scene.id,
              shootingDayId: day.id,
              severity: ScheduleConflictSeverity.blocking,
              message:
                  'Cảnh ${scene.sceneNumber} là nội cảnh nhưng địa điểm quay không hỗ trợ nội cảnh.',
            ),
          );
        }
        if (scene.settingType == 'EXT' &&
            !scene.shootingLocationSupportsExterior) {
          conflicts.add(
            ScheduleConflict(
              sceneId: scene.id,
              shootingDayId: day.id,
              severity: ScheduleConflictSeverity.blocking,
              message:
                  'Cảnh ${scene.sceneNumber} là ngoại cảnh nhưng địa điểm quay không hỗ trợ ngoại cảnh.',
            ),
          );
        }

        for (final resource in scene.resources) {
          resourceUsage.update(
            resource.id,
            (value) => value + resource.requiredQuantity,
            ifAbsent: () => resource.requiredQuantity,
          );
          resourcesById[resource.id] = resource;
          if (resource.requiredQuantity > resource.quantityTotal) {
            conflicts.add(
              ScheduleConflict(
                sceneId: scene.id,
                shootingDayId: day.id,
                severity: ScheduleConflictSeverity.blocking,
                message:
                    'Cảnh ${scene.sceneNumber} cần ${resource.requiredQuantity} ${resource.name}, '
                    'nhưng chỉ có ${resource.quantityTotal}.',
              ),
            );
          }
        }

        final start = _toMinutes(item.plannedStartTime);
        final end = _toMinutes(item.plannedEndTime);
        if (start != null && end != null) {
          if (start >= end) {
            conflicts.add(
              ScheduleConflict(
                sceneId: scene.id,
                shootingDayId: day.id,
                severity: ScheduleConflictSeverity.blocking,
                message:
                    'Cảnh ${scene.sceneNumber} có giờ bắt đầu sau hoặc bằng giờ kết thúc.',
              ),
            );
          } else {
            ranges.add(
              _TimeRange(
                sceneId: scene.id,
                sceneNumber: scene.sceneNumber,
                start: start,
                end: end,
              ),
            );
          }
        }
      }

      for (final entry in resourceUsage.entries) {
        final resource = resourcesById[entry.key]!;
        if (entry.value > resource.quantityTotal) {
          conflicts.add(
            ScheduleConflict(
              shootingDayId: day.id,
              severity: ScheduleConflictSeverity.blocking,
              message: '${day.title} cần ${entry.value} ${resource.name}, '
                  'nhưng chỉ có ${resource.quantityTotal}.',
            ),
          );
        }
      }

      ranges.sort((a, b) => a.start.compareTo(b.start));
      for (var index = 1; index < ranges.length; index++) {
        final previous = ranges[index - 1];
        final current = ranges[index];
        if (current.start < previous.end) {
          conflicts.add(
            ScheduleConflict(
              sceneId: current.sceneId,
              shootingDayId: day.id,
              severity: ScheduleConflictSeverity.blocking,
              message:
                  'Cảnh ${current.sceneNumber} bị chồng giờ với cảnh ${previous.sceneNumber}.',
            ),
          );
        }
      }
    }

    if (editingCompletedDay) {
      conflicts.add(
        ScheduleConflict(
          severity: ScheduleConflictSeverity.blocking,
          message: 'Không thể sửa ngày quay đã hoàn tất.',
        ),
      );
    }
    if (!userCanConfirm) {
      conflicts.add(
        ScheduleConflict(
          severity: ScheduleConflictSeverity.blocking,
          message: 'Bạn không có quyền xác nhận lịch quay.',
        ),
      );
    }

    return conflicts;
  }

  static int? _toMinutes(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }
}

class _TimeRange {
  _TimeRange({
    required this.sceneId,
    required this.sceneNumber,
    required this.start,
    required this.end,
  });

  final int sceneId;
  final int sceneNumber;
  final int start;
  final int end;
}
