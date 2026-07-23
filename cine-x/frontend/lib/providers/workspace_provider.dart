import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/permissions/permission_service.dart';
import '../models/cinex_models.dart';
import '../repositories/cinex_repository.dart';
import '../services/schedule_conflict_service.dart';

class WorkspaceProvider extends ChangeNotifier {
  WorkspaceProvider(this.repository, this.project);

  final CineXRepository repository;
  final Project project;

  Dashboard? dashboard;
  AnalyticsSummary? analytics;
  List<ProjectMember> members = [];
  List<Act> acts = [];
  List<StoryCharacter> characters = [];
  List<StoryLocation> storyLocations = [];
  List<ShootingLocation> shootingLocations = [];
  List<FilmResource> resources = [];
  List<Scene> scenes = [];
  List<PlannerGroup> planner = [];
  List<CharacterFrequency> characterFrequency = [];
  List<ShootingDay> shootingDays = [];
  List<ShootingDay> selectedDateDays = [];
  List<Scene> unscheduledScenes = [];
  List<ScheduleConflict> conflicts = [];
  List<String> scheduleWarnings = [];
  Set<ProjectPermission> permissionSet = {};
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;
  String? errorMessage;

  bool get loading => isLoading;
  String? get error => errorMessage;
  List<StoryLocation> get locations => storyLocations;

  bool can(ProjectPermission permission) => permissionSet.contains(permission);

  Future<void> loadAll() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      permissionSet = await repository.permissions(project.id);
      await Future.wait([
        loadDashboard(),
        loadMembers(),
        loadActs(),
        loadCharacters(),
        loadStoryLocations(),
        loadShootingLocations(),
        loadResources(),
        loadScenes(),
        loadPlanner(),
        loadAnalytics(),
        loadCalendar(),
      ]);
    } catch (ex) {
      errorMessage = ex.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async {
    dashboard = await repository.dashboard(project.id);
  }

  Future<void> loadMembers() async {
    members = await repository.members(project.id);
  }

  Future<void> loadActs() async {
    acts = await repository.acts(project.id);
  }

  Future<void> loadCharacters() async {
    characters = await repository.characters(project.id);
  }

  Future<void> loadStoryLocations() async {
    storyLocations = await repository.storyLocations(project.id);
  }

  Future<void> loadLocations() => loadStoryLocations();

  Future<void> loadShootingLocations() async {
    shootingLocations = await repository.shootingLocations(project.id);
  }

  Future<void> loadResources({String? search, String? resourceType}) async {
    resources = await repository.resources(
      project.id,
      search: search,
      resourceType: resourceType,
    );
  }

  Future<void> loadScenes({
    String? status,
    int? characterId,
    int? locationId,
  }) async {
    scenes = await repository.scenes(
      project.id,
      status: status,
      characterId: characterId,
      locationId: locationId,
    );
  }

  Future<void> loadPlanner() async {
    planner = await repository.planner(project.id);
  }

  Future<void> loadAnalytics() async {
    analytics = await repository.analyticsSummary(project.id);
    characterFrequency = await repository.characterFrequency(project.id);
  }

  Future<void> loadCalendar({DateTime? date}) async {
    if (date != null) selectedDate = date;
    try {
      shootingDays =
          await repository.shootingDays(project.id, month: selectedDate);
      selectedDateDays = await repository.shootingDays(
        project.id,
        date: selectedDate,
      );
      unscheduledScenes = await repository.scenes(
        project.id,
        productionStatus: 'READY_FOR_PLANNING',
        unscheduledOnly: true,
      );
      conflicts = await repository.scheduleConflicts(project.id);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> createAct(String title, int order, {String? description}) {
    return _mutate(
      () => repository.createAct(project.id, {
        'title': title,
        'sequenceOrder': order,
        'description': description,
      }),
    );
  }

  Future<bool> updateAct(
    Act act,
    String title,
    int order, {
    String? description,
  }) {
    return _mutate(
      () => repository.updateAct(project.id, act.id, {
        'title': title,
        'sequenceOrder': order,
        'description': description,
      }),
    );
  }

  Future<bool> deleteAct(Act act) {
    return _mutate(() => repository.deleteAct(project.id, act.id));
  }

  Future<bool> addMember({
    required String email,
    required String role,
    String? fullName,
  }) {
    return _mutate(
      () => repository.addMember(
        project.id,
        email: email,
        role: role,
        fullName: fullName,
      ),
    );
  }

  Future<bool> updateMember(ProjectMember member, String role) {
    return _mutate(
      () => repository.updateMemberRole(project.id, member.userId, role),
    );
  }

  Future<bool> deleteMember(ProjectMember member) {
    return _mutate(
      () => repository.deleteMember(project.id, member.userId),
    );
  }

  Future<bool> createCharacter(
    String name,
    String roleType, {
    String? description,
    String? psychologicalDescription,
    String? appearanceDescription,
    String? imagePath,
  }) {
    return _mutate(
      () => repository.createCharacter(project.id, {
        'name': name,
        'roleType': roleType,
        'description': description,
        'psychologicalDescription': psychologicalDescription,
        'appearanceDescription': appearanceDescription,
        'imagePath': imagePath,
      }),
    );
  }

  Future<bool> updateCharacter(
    int characterId, {
    required String name,
    required String roleType,
    String? psychologicalDescription,
    String? appearanceDescription,
    String? imagePath,
  }) {
    return _mutate(
      () => repository.updateCharacter(project.id, characterId, {
        'name': name,
        'roleType': roleType,
        'psychologicalDescription': psychologicalDescription,
        'appearanceDescription': appearanceDescription,
        if (imagePath != null) 'imagePath': imagePath,
      }),
    );
  }

  Future<bool> uploadCharacterImage(StoryCharacter character, XFile file) {
    return _mutate(
      () => repository.uploadCharacterImage(project.id, character.id, file),
    );
  }

  Future<bool> deleteCharacter(StoryCharacter character) {
    return _mutate(() => repository.deleteCharacter(project.id, character.id));
  }

  Future<bool> createLocation(
    String name,
    String settingType,
    String timeOfDay, {
    String? notes,
  }) {
    return createStoryLocation(name, notes: notes);
  }

  Future<bool> createStoryLocation(
    String name, {
    String? description,
    String? notes,
  }) {
    return _mutate(
      () => repository.createStoryLocation(project.id, {
        'name': name,
        'description': description,
        'notes': notes,
      }),
    );
  }

  Future<bool> updateStoryLocation(
    int id, {
    required String name,
    String? description,
    String? notes,
  }) {
    return _mutate(
      () => repository.updateStoryLocation(project.id, id, {
        'name': name,
        'description': description,
        'notes': notes,
      }),
    );
  }

  Future<bool> archiveStoryLocation(StoryLocation location) {
    return _mutate(
      () => repository.archiveStoryLocation(project.id, location.id),
    );
  }

  Future<bool> createShootingLocation(Map<String, dynamic> body) {
    return _mutate(() => repository.createShootingLocation(project.id, body));
  }

  Future<bool> updateShootingLocation(int id, Map<String, dynamic> body) {
    return _mutate(
        () => repository.updateShootingLocation(project.id, id, body));
  }

  Future<bool> archiveShootingLocation(ShootingLocation location) {
    return _mutate(
      () => repository.archiveShootingLocation(project.id, location.id),
    );
  }

  Future<bool> createResource(Map<String, dynamic> body) {
    return _mutate(() => repository.createResource(project.id, body));
  }

  Future<bool> updateResource(int id, Map<String, dynamic> body) {
    return _mutate(() => repository.updateResource(project.id, id, body));
  }

  Future<bool> archiveResource(FilmResource resource) {
    return _mutate(() => repository.archiveResource(project.id, resource.id));
  }

  Future<bool> createScene({
    required int sceneNumber,
    required int actId,
    required int locationId,
    required String summary,
    required String status,
    String? title,
    int? plannedShootingLocationId,
    String settingType = 'INT',
    String timeOfDay = 'DAY',
    int? estimatedMinutes,
    int priority = 3,
    String productionStatus = 'NOT_READY',
    List<int> characterIds = const [],
    List<Map<String, Object?>> resourceRequirements = const [],
  }) {
    return _mutate(
      () => repository.createScene(project.id, {
        'sceneNumber': sceneNumber,
        'actId': actId,
        'storyLocationId': locationId,
        'plannedShootingLocationId': plannedShootingLocationId,
        'title': title,
        'summary': summary,
        'writingStatus': status,
        'productionStatus': productionStatus,
        'settingType': settingType,
        'timeOfDay': timeOfDay,
        'estimatedDurationMinutes': estimatedMinutes,
        'priority': priority,
        'characterIds': characterIds,
        'resourceRequirements': resourceRequirements,
      }),
    );
  }

  Future<bool> updateSceneStatus(Scene scene, String status) {
    return _mutate(
      () => repository.updateSceneStatus(project.id, scene.id, status),
    );
  }

  Future<bool> updateScene(
    int sceneId, {
    required int sceneNumber,
    required int actId,
    required int locationId,
    required String summary,
    required String status,
    String? title,
    int? plannedShootingLocationId,
    String settingType = 'INT',
    String timeOfDay = 'DAY',
    int? estimatedMinutes,
    int priority = 3,
    String productionStatus = 'NOT_READY',
    List<int> characterIds = const [],
    List<Map<String, Object?>> resourceRequirements = const [],
  }) {
    return _mutate(
      () => repository.updateScene(project.id, sceneId, {
        'sceneNumber': sceneNumber,
        'actId': actId,
        'storyLocationId': locationId,
        'plannedShootingLocationId': plannedShootingLocationId,
        'title': title,
        'summary': summary,
        'writingStatus': status,
        'productionStatus': productionStatus,
        'settingType': settingType,
        'timeOfDay': timeOfDay,
        'estimatedDurationMinutes': estimatedMinutes,
        'priority': priority,
        'characterIds': characterIds,
        'resourceRequirements': resourceRequirements,
      }),
    );
  }

  Future<bool> deleteScene(Scene scene) {
    return _mutate(() => repository.deleteScene(project.id, scene.id));
  }

  Future<bool> createShootingDay({
    required DateTime date,
    required String title,
    int? maxMinutes,
    String? notes,
    List<int> sceneIdsToAdd = const [],
  }) {
    final previousDate = selectedDate;
    selectedDate = date;
    return _mutate(
      () async {
        final day = await repository.createShootingDay(
          project.id,
          date: date,
          title: title,
          maxMinutes: maxMinutes,
          notes: notes,
        );
        for (final sceneId in sceneIdsToAdd) {
          await repository.addSceneToShootingDay(
            project.id,
            day.id,
            sceneId,
          );
        }
        return day;
      },
    ).then((ok) {
      if (!ok) {
        selectedDate = previousDate;
        notifyListeners();
      }
      return ok;
    });
  }

  Future<bool> updateShootingDay(
    int shootingDayId, {
    required DateTime date,
    required String title,
    int? maxMinutes,
    String? notes,
    List<int> sceneIdsToAdd = const [],
  }) {
    final previousDate = selectedDate;
    selectedDate = date;
    return _mutate(
      () async {
        final day = await repository.updateShootingDay(
          project.id,
          shootingDayId,
          date: date,
          title: title,
          maxMinutes: maxMinutes,
          notes: notes,
        );
        for (final sceneId in sceneIdsToAdd) {
          await repository.addSceneToShootingDay(
            project.id,
            shootingDayId,
            sceneId,
          );
        }
        return day;
      },
    ).then((ok) {
      if (!ok) {
        selectedDate = previousDate;
        notifyListeners();
      }
      return ok;
    });
  }

  Future<bool> addSceneToShootingDay(
    int shootingDayId,
    int sceneId, {
    String? plannedStartTime,
    String? plannedEndTime,
  }) {
    return _mutate(
      () => repository.addSceneToShootingDay(
        project.id,
        shootingDayId,
        sceneId,
        plannedStartTime: plannedStartTime,
        plannedEndTime: plannedEndTime,
      ),
    );
  }

  Future<bool> updateShootingDaySceneTime(
    int shootingDayId,
    int sceneId, {
    String? plannedStartTime,
    String? plannedEndTime,
  }) {
    return _mutate(
      () => repository.updateShootingDaySceneTime(
        project.id,
        shootingDayId,
        sceneId,
        plannedStartTime: plannedStartTime,
        plannedEndTime: plannedEndTime,
      ),
    );
  }

  Future<bool> removeSceneFromShootingDay(int shootingDayId, int sceneId) {
    return _mutate(
      () => repository.removeSceneFromShootingDay(
        project.id,
        shootingDayId,
        sceneId,
      ),
    );
  }

  Future<bool> reorderShootingDayScenes(
    int shootingDayId,
    List<int> sceneIds,
  ) {
    return _mutate(
      () => repository.reorderShootingDayScenes(
          project.id, shootingDayId, sceneIds),
    );
  }

  Future<bool> updateShootingDayStatus(int shootingDayId, String status) {
    return _mutate(
      () =>
          repository.updateShootingDayStatus(project.id, shootingDayId, status),
    );
  }

  Future<bool> generateSuggestedSchedule(DateTime startDate) async {
    scheduleWarnings = [];
    return _mutate(() async {
      scheduleWarnings = await repository.generateSuggestedSchedule(
        project.id,
        startDate: startDate,
      );
      return scheduleWarnings;
    });
  }

  Future<Uint8List?> exportPdf() async {
    try {
      return await repository.exportPdf(project.id);
    } catch (ex) {
      errorMessage = ex.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    }
  }

  Future<bool> _mutate(Future<Object?> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      await Future.wait([
        loadDashboard(),
        loadMembers(),
        loadActs(),
        loadCharacters(),
        loadStoryLocations(),
        loadShootingLocations(),
        loadResources(),
        loadScenes(),
        loadPlanner(),
        loadAnalytics(),
        loadCalendar(),
      ]);
      return true;
    } catch (ex) {
      errorMessage = ex.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
