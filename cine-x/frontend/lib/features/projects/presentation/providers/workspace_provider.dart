import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/models/cinex_models.dart';
import '../../data/repositories/cinex_repository.dart';

class WorkspaceProvider extends ChangeNotifier {
  WorkspaceProvider(this.repository, this.project);

  final CineXRepository repository;
  final Project project;

  Dashboard? dashboard;
  AnalyticsSummary? analytics;
  List<Act> acts = [];
  List<StoryCharacter> characters = [];
  List<StoryLocation> locations = [];
  List<Scene> scenes = [];
  List<PlannerGroup> planner = [];
  List<CharacterFrequency> characterFrequency = [];
  bool loading = false;
  String? error;

  Future<void> loadAll() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([
        loadDashboard(),
        loadActs(),
        loadCharacters(),
        loadLocations(),
        loadScenes(),
        loadPlanner(),
        loadAnalytics(),
      ]);
    } catch (_) {
      error ??= 'Unable to load workspace';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadDashboard() async {
    dashboard = await repository.dashboard(project.id);
  }

  Future<void> loadActs() async {
    acts = await repository.acts(project.id);
  }

  Future<void> loadCharacters() async {
    characters = await repository.characters(project.id);
  }

  Future<void> loadLocations() async {
    locations = await repository.locations(project.id);
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

  Future<bool> createAct(String title, int order, {String? description}) async {
    return _mutate(
      () => repository.createAct(project.id, {
        'title': title,
        'sequenceOrder': order,
        'description': description,
      }),
    );
  }

  Future<bool> createCharacter(
    String name,
    String roleType, {
    String? description,
  }) async {
    return _mutate(
      () => repository.createCharacter(project.id, {
        'name': name,
        'roleType': roleType,
        'description': description,
      }),
    );
  }

  Future<bool> uploadCharacterImage(StoryCharacter character, XFile file) {
    return _mutate(
      () => repository.uploadCharacterImage(project.id, character.id, file),
    );
  }

  Future<bool> createLocation(
    String name,
    String settingType,
    String timeOfDay, {
    String? notes,
  }) async {
    return _mutate(
      () => repository.createLocation(project.id, {
        'name': name,
        'settingType': settingType,
        'timeOfDay': timeOfDay,
        'notes': notes,
      }),
    );
  }

  Future<bool> createScene({
    required int sceneNumber,
    required int actId,
    required int locationId,
    required String summary,
    required String status,
    String? title,
    int? estimatedMinutes,
    List<int> characterIds = const [],
  }) {
    return _mutate(
      () => repository.createScene(project.id, {
        'sceneNumber': sceneNumber,
        'actId': actId,
        'locationId': locationId,
        'title': title,
        'summary': summary,
        'status': status,
        'estimatedMinutes': estimatedMinutes,
        'characterIds': characterIds,
      }),
    );
  }

  Future<bool> updateSceneStatus(Scene scene, String status) {
    return _mutate(
      () => repository.updateSceneStatus(project.id, scene.id, status),
    );
  }

  Future<Uint8List?> exportPdf() async {
    try {
      return await repository.exportPdf(project.id);
    } on AppException catch (ex) {
      error = ex.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> _mutate(Future<Object?> Function() action) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      await Future.wait([
        loadDashboard(),
        loadActs(),
        loadCharacters(),
        loadLocations(),
        loadScenes(),
        loadPlanner(),
        loadAnalytics(),
      ]);
      return true;
    } on AppException catch (ex) {
      error = ex.message;
      return false;
    } catch (_) {
      error = 'Action failed';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
