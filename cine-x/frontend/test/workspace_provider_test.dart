import 'package:cine_x/core/permissions/permission_service.dart';
import 'package:cine_x/core/storage/session_storage.dart';
import 'package:cine_x/models/cinex_models.dart';
import 'package:cine_x/providers/workspace_provider.dart';
import 'package:cine_x/repositories/cinex_repository.dart';
import 'package:cine_x/services/schedule_conflict_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test('loadCalendar notifies listeners after changing month', () async {
    final db = _FakeDatabase();
    final repository = _CalendarRepository(db);
    final provider = WorkspaceProvider(
      repository,
      Project(id: 1, ownerId: 1, title: 'CINE-X'),
    );
    var notifications = 0;
    provider.addListener(() => notifications++);

    final targetMonth = DateTime(2026, 6);
    await provider.loadCalendar(date: targetMonth);

    expect(provider.selectedDate, targetMonth);
    expect(repository.monthRequests, [targetMonth]);
    expect(repository.dateRequests, [targetMonth]);
    expect(provider.shootingDays.single.shootingDate, targetMonth);
    expect(provider.selectedDateDays.single.shootingDate, targetMonth);
    expect(notifications, greaterThan(0));
  });
}

class _CalendarRepository extends CineXRepository {
  _CalendarRepository(Database db)
      : super(
          db,
          MemorySessionStorage(),
          PermissionService(db),
        );

  final monthRequests = <DateTime>[];
  final dateRequests = <DateTime>[];

  @override
  Future<List<ShootingDay>> shootingDays(
    int projectId, {
    DateTime? month,
    DateTime? date,
  }) async {
    if (month != null) {
      monthRequests.add(month);
      return [_shootingDay(month)];
    }
    if (date != null) {
      dateRequests.add(date);
      return [_shootingDay(date)];
    }
    return [];
  }

  @override
  Future<List<Scene>> scenes(
    int projectId, {
    String? search,
    int? actId,
    int? locationId,
    int? characterId,
    String? settingType,
    String? timeOfDay,
    String? status,
    String? productionStatus,
    bool unscheduledOnly = false,
  }) async {
    return [];
  }

  @override
  Future<List<ScheduleConflict>> scheduleConflicts(int projectId) async {
    return [];
  }
}

ShootingDay _shootingDay(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return ShootingDay(
    id: date.month,
    projectId: 1,
    shootingDate: day,
    title: 'Ngày quay',
    status: 'DRAFT',
    maxMinutes: 480,
    createdAt: day,
    updatedAt: day,
  );
}

class _FakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
