import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../../core/network/api_client.dart';
import '../models/cinex_models.dart';

class CineXRepository {
  CineXRepository(this._client);

  final ApiClient _client;

  Future<List<Project>> projects({String? search}) async {
    final data = await _client.get(
      '/projects',
      query: {'search': search, 'size': 50, 'sort': 'updatedAt,desc'},
    );
    return ApiPage.fromJson(data, Project.fromJson).items;
  }

  Future<Project> createProject(Map<String, dynamic> body) async {
    final data = await _client.post('/projects', body: body);
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<Project> updateProject(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    final data = await _client.put('/projects/$projectId', body: body);
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteProject(int projectId) =>
      _client.delete('/projects/$projectId');

  Future<Dashboard> dashboard(int projectId) async {
    final data = await _client.get('/projects/$projectId/dashboard');
    return Dashboard.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Act>> acts(int projectId) async {
    final data = await _client.get('/projects/$projectId/acts');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Act.fromJson)
        .toList();
  }

  Future<Act> createAct(int projectId, Map<String, dynamic> body) async {
    final data = await _client.post('/projects/$projectId/acts', body: body);
    return Act.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteAct(int projectId, int actId) =>
      _client.delete('/projects/$projectId/acts/$actId');

  Future<List<StoryCharacter>> characters(
    int projectId, {
    String? search,
    String? roleType,
  }) async {
    final data = await _client.get(
      '/projects/$projectId/characters',
      query: {'search': search, 'roleType': roleType, 'size': 100},
    );
    return ApiPage.fromJson(data, StoryCharacter.fromJson).items;
  }

  Future<StoryCharacter> createCharacter(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    final data = await _client.post(
      '/projects/$projectId/characters',
      body: body,
    );
    return StoryCharacter.fromJson(data as Map<String, dynamic>);
  }

  Future<StoryCharacter> uploadCharacterImage(
    int projectId,
    int characterId,
    XFile file,
  ) async {
    final bytes = await file.readAsBytes();
    final type = lookupMimeType(file.name, headerBytes: bytes) ?? 'image/jpeg';
    final data = await _client.multipart(
      '/projects/$projectId/characters/$characterId/image',
      fieldName: 'file',
      bytes: bytes,
      filename: file.name,
      contentType: type,
    );
    return StoryCharacter.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteCharacter(int projectId, int characterId) =>
      _client.delete('/projects/$projectId/characters/$characterId');

  Future<List<StoryLocation>> locations(
    int projectId, {
    String? search,
    String? settingType,
    String? timeOfDay,
  }) async {
    final data = await _client.get(
      '/projects/$projectId/locations',
      query: {
        'search': search,
        'settingType': settingType,
        'timeOfDay': timeOfDay,
        'size': 100,
      },
    );
    return ApiPage.fromJson(data, StoryLocation.fromJson).items;
  }

  Future<StoryLocation> createLocation(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    final data = await _client.post(
      '/projects/$projectId/locations',
      body: body,
    );
    return StoryLocation.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteLocation(int projectId, int locationId) =>
      _client.delete('/projects/$projectId/locations/$locationId');

  Future<List<Scene>> scenes(
    int projectId, {
    String? search,
    int? actId,
    int? locationId,
    int? characterId,
    String? settingType,
    String? timeOfDay,
    String? status,
  }) async {
    final data = await _client.get(
      '/projects/$projectId/scenes',
      query: {
        'search': search,
        'actId': actId,
        'locationId': locationId,
        'characterId': characterId,
        'settingType': settingType,
        'timeOfDay': timeOfDay,
        'status': status,
        'size': 200,
        'sort': 'sceneNumber,asc',
      },
    );
    return ApiPage.fromJson(data, Scene.fromJson).items;
  }

  Future<Scene> createScene(int projectId, Map<String, dynamic> body) async {
    final data = await _client.post('/projects/$projectId/scenes', body: body);
    return Scene.fromJson(data as Map<String, dynamic>);
  }

  Future<Scene> updateSceneStatus(
    int projectId,
    int sceneId,
    String status,
  ) async {
    final data = await _client.patch(
      '/projects/$projectId/scenes/$sceneId/status',
      body: {'status': status},
    );
    return Scene.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteScene(int projectId, int sceneId) =>
      _client.delete('/projects/$projectId/scenes/$sceneId');

  Future<List<PlannerGroup>> planner(int projectId) async {
    final data = await _client.get('/projects/$projectId/planner/by-location');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(PlannerGroup.fromJson)
        .toList();
  }

  Future<AnalyticsSummary> analyticsSummary(int projectId) async {
    final data = await _client.get('/projects/$projectId/analytics/summary');
    return AnalyticsSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CharacterFrequency>> characterFrequency(int projectId) async {
    final data = await _client.get(
      '/projects/$projectId/analytics/character-frequency',
    );
    final items = ((data as Map<String, dynamic>)['items'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    return items.map(CharacterFrequency.fromJson).toList();
  }

  Future<Uint8List> exportPdf(int projectId) =>
      _client.getBytes('/projects/$projectId/export/pdf');
}
