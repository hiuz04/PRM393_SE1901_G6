import 'package:cine_x/core/permissions/permission_service.dart';
import 'package:cine_x/core/validators/form_validators.dart';
import 'package:cine_x/models/cinex_models.dart';
import 'package:cine_x/services/production_schedule_optimizer.dart';
import 'package:cine_x/services/schedule_conflict_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('permission matrix', () {
    test('OWNER has all project permissions', () {
      final permissions = PermissionService.permissionsForRoles(['OWNER']);

      expect(permissions, containsAll(ProjectPermission.values));
    });

    test('SCREENWRITER and PRODUCER are scoped by project role', () {
      final writer = PermissionService.permissionsForRoles(['SCREENWRITER']);
      final producer = PermissionService.permissionsForRoles(['PRODUCER']);
      final assistant =
          PermissionService.permissionsForRoles(['ASSISTANT_DIRECTOR']);
      final crew = PermissionService.permissionsForRoles(['CREW']);
      final viewer = PermissionService.permissionsForRoles(['VIEWER']);
      final combined = PermissionService.permissionsForRoles([
        'SCREENWRITER',
        'PRODUCER',
      ]);

      expect(writer, contains(ProjectPermission.manageStory));
      expect(writer, isNot(contains(ProjectPermission.manageSchedule)));
      expect(producer, contains(ProjectPermission.manageResources));
      expect(producer, isNot(contains(ProjectPermission.manageStory)));
      expect(assistant, contains(ProjectPermission.manageSchedule));
      expect(crew, contains(ProjectPermission.viewSchedule));
      expect(crew, isNot(contains(ProjectPermission.manageSchedule)));
      expect(viewer, isEmpty);
      expect(combined, contains(ProjectPermission.manageStory));
      expect(combined, contains(ProjectPermission.manageSchedule));
    });
  });

  group('validators', () {
    test(
        'character, scene, coordinate, and resource validators reject bad data',
        () {
      expect(CharacterValidators.name('A'), isNotNull);
      expect(CharacterValidators.name('Linh'), isNull);
      expect(SceneValidators.sceneNumber('0'), isNotNull);
      expect(SceneValidators.titleOrSummary('', ''), isNotNull);
      expect(FormValidators.optionalLatitude('91', '106'), isNotNull);
      expect(FormValidators.optionalLongitude('106', '10'), isNull);
      expect(
        ResourceValidators.requiredQuantity(
          requiredQuantity: 4,
          totalQuantity: 3,
        ),
        isNotNull,
      );
    });

    test('shooting day max duration validator rejects non-positive values', () {
      expect(ShootingDayValidators.maxMinutes('0'), isNotNull);
      expect(ShootingDayValidators.maxMinutes('480'), isNull);
    });

    test('time range validator requires a valid ordered HH:mm pair', () {
      expect(FormValidators.timeOrder('', ''), isNull);
      expect(FormValidators.timeOrder('08:00', ''), isNotNull);
      expect(FormValidators.timeOrder('99:00', '10:00'), isNotNull);
      expect(FormValidators.timeOrder('10:30', '10:00'), isNotNull);
      expect(FormValidators.timeOrder('08:00', '10:00'), isNull);
    });
  });

  group('schedule conflict detection', () {
    test(
        'detects duplicate scenes, duration overflow, aggregate resources, and overlap',
        () {
      final sharedResource =
          _resource(id: 7, name: 'Camera', required: 2, total: 3);
      final sceneA = _scene(
        id: 1,
        number: 1,
        duration: 40,
        resources: [sharedResource],
      );
      final sceneB = _scene(
        id: 2,
        number: 2,
        duration: 35,
        resources: [sharedResource],
      );
      final dayOne = _day(
        id: 10,
        maxMinutes: 60,
        scenes: [
          _dayScene(dayId: 10, scene: sceneA, start: '08:00', end: '08:45'),
          _dayScene(dayId: 10, scene: sceneB, start: '08:30', end: '09:00'),
        ],
      );
      final dayTwo = _day(
        id: 11,
        scenes: [_dayScene(dayId: 11, scene: sceneA)],
      );

      final conflicts = const ScheduleConflictService().detect(
        shootingDays: [dayOne, dayTwo],
        scenesById: {1: sceneA, 2: sceneB},
      );

      expect(conflicts.where((item) => item.blocking), isNotEmpty);
      expect(
        conflicts.map((item) => item.message).join('\n'),
        allOf(
          contains('vượt quá giới hạn trong ngày'),
          contains('nhiều ngày quay còn hiệu lực'),
          contains('cần 4 Camera'),
          contains('chồng giờ với cảnh'),
        ),
      );
    });

    test('detects missing or incompatible shooting locations', () {
      final missingLocation = _scene(
        id: 1,
        number: 1,
        shootingLocationId: null,
      );
      final exteriorAtInteriorOnlyLocation = _scene(
        id: 2,
        number: 2,
        settingType: 'EXT',
        supportsExterior: false,
      );

      final conflicts = const ScheduleConflictService().detect(
        shootingDays: [
          _day(
            id: 10,
            scenes: [
              _dayScene(dayId: 10, scene: missingLocation),
              _dayScene(dayId: 10, scene: exteriorAtInteriorOnlyLocation),
            ],
          ),
        ],
        scenesById: {
          1: missingLocation,
          2: exteriorAtInteriorOnlyLocation,
        },
      );

      expect(
        conflicts.map((item) => item.message).join('\n'),
        allOf(
          contains('chưa có địa điểm quay'),
          contains('không hỗ trợ ngoại cảnh'),
        ),
      );
    });
  });

  group('production schedule optimizer', () {
    test('generates draft days without duplicates and respects max duration',
        () {
      final project = Project(
        id: 1,
        ownerId: 1,
        title: 'CINE-X',
        maxShootingMinutesPerDay: 60,
      );
      final result = const ProductionScheduleOptimizer().generate(
        project: project,
        readyScenes: [
          _scene(id: 3, number: 3, shootingLocationId: null),
          _scene(id: 2, number: 2, duration: 20, timeOfDay: 'DAY'),
          _scene(id: 1, number: 1, duration: 30, timeOfDay: 'DAY'),
        ],
        startDate: DateTime(2026, 1, 1),
      );

      final scheduledIds = [
        for (final day in result.days)
          for (final item in day.scenes) item.scene.id,
      ];

      expect(result.warnings.join('\n'), contains('chưa có địa điểm quay'));
      expect(scheduledIds.length, scheduledIds.toSet().length);
      expect(result.days.every((day) => day.totalMinutes <= day.maxMinutes),
          isTrue);
      expect(result.days.first.date, DateTime(2026, 1, 1));
    });
  });
}

Scene _scene({
  required int id,
  required int number,
  int? shootingLocationId = 1,
  int duration = 30,
  String settingType = 'INT',
  String timeOfDay = 'DAY',
  bool supportsInterior = true,
  bool supportsExterior = true,
  List<SceneResource> resources = const [],
}) {
  return Scene(
    id: id,
    projectId: 1,
    actId: 1,
    actTitle: 'Act 1',
    storyLocationId: 1,
    storyLocationName: 'Cafe',
    plannedShootingLocationId: shootingLocationId,
    plannedShootingLocationName: shootingLocationId == null ? null : 'Cafe ABC',
    plannedShootingLocationAddress:
        shootingLocationId == null ? null : '25 Nguyen Hue',
    shootingLocationSupportsInterior: supportsInterior,
    shootingLocationSupportsExterior: supportsExterior,
    settingType: settingType,
    timeOfDay: timeOfDay,
    sceneNumber: number,
    title: 'Scene $number',
    summary: 'Summary $number',
    writingStatus: 'DONE',
    productionStatus: 'READY_FOR_PLANNING',
    estimatedDurationMinutes: duration,
    priority: 1,
    characters: const [],
    resources: resources,
  );
}

SceneResource _resource({
  required int id,
  required String name,
  required int required,
  required int total,
}) {
  return SceneResource(
    id: id,
    name: name,
    resourceType: 'EQUIPMENT',
    quantityTotal: total,
    requiredQuantity: required,
  );
}

ShootingDay _day({
  required int id,
  int maxMinutes = 480,
  List<ShootingDayScene> scenes = const [],
}) {
  return ShootingDay(
    id: id,
    projectId: 1,
    shootingDate: DateTime(2026, 1, id),
    title: 'Day $id',
    status: 'DRAFT',
    maxMinutes: maxMinutes,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    scenes: scenes,
  );
}

ShootingDayScene _dayScene({
  required int dayId,
  required Scene scene,
  String? start,
  String? end,
}) {
  return ShootingDayScene(
    shootingDayId: dayId,
    scene: scene,
    sequenceOrder: 1,
    plannedStartTime: start,
    plannedEndTime: end,
  );
}
