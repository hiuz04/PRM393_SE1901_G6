class ApiPage<T> {
  ApiPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;

  static ApiPage<T> fromJson<T>(
    dynamic json,
    T Function(Map<String, dynamic>) mapper,
  ) {
    if (json is List) {
      return ApiPage(
        items: json.cast<Map<String, dynamic>>().map(mapper).toList(),
        page: 0,
        size: json.length,
        totalElements: json.length,
      );
    }
    final map = json as Map<String, dynamic>;
    final content =
        (map['content'] as List? ?? const []).cast<Map<String, dynamic>>();
    return ApiPage(
      items: content.map(mapper).toList(),
      page: map['number'] as int? ?? 0,
      size: map['size'] as int? ?? content.length,
      totalElements: map['totalElements'] as int? ?? content.length,
    );
  }
}

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.systemRole,
  });

  final int id;
  final String email;
  final String displayName;
  final String systemRole;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        systemRole: json['systemRole'] as String? ?? 'USER',
      );
}

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        accessToken: json['accessToken'] as String,
        tokenType: json['tokenType'] as String? ?? 'Bearer',
        expiresIn: json['expiresIn'] as int? ?? 0,
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class Project {
  Project({
    required this.id,
    required this.ownerId,
    required this.title,
    this.genre,
    this.description,
    this.startDate,
    this.posterUrl,
    required this.status,
    this.deleted = false,
    required this.progressPercent,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int ownerId;
  final String title;
  final String? genre;
  final String? description;
  final DateTime? startDate;
  final String? posterUrl;
  final String status;
  final bool deleted;
  final double progressPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as int,
        ownerId: json['ownerId'] as int,
        title: json['title'] as String,
        genre: json['genre'] as String?,
        description: json['description'] as String?,
        startDate: json['startDate'] == null
            ? null
            : DateTime.parse(json['startDate'] as String),
        posterUrl: json['posterUrl'] as String?,
        status: json['status'] as String? ?? 'ACTIVE',
        deleted: json['deleted'] as bool? ?? false,
        progressPercent: (json['progressPercent'] as num? ?? 0).toDouble(),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );
}

class Dashboard {
  Dashboard({
    required this.totalActs,
    required this.totalCharacters,
    required this.totalLocations,
    required this.totalScenes,
    required this.todoScenes,
    required this.inProgressScenes,
    required this.doneScenes,
    required this.progressPercent,
  });

  final int totalActs;
  final int totalCharacters;
  final int totalLocations;
  final int totalScenes;
  final int todoScenes;
  final int inProgressScenes;
  final int doneScenes;
  final double progressPercent;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        totalActs: json['totalActs'] as int? ?? 0,
        totalCharacters: json['totalCharacters'] as int? ?? 0,
        totalLocations: json['totalLocations'] as int? ?? 0,
        totalScenes: json['totalScenes'] as int? ?? 0,
        todoScenes: json['todoScenes'] as int? ?? 0,
        inProgressScenes: json['inProgressScenes'] as int? ?? 0,
        doneScenes: json['doneScenes'] as int? ?? 0,
        progressPercent: (json['progressPercent'] as num? ?? 0).toDouble(),
      );
}

class Act {
  Act({
    required this.id,
    required this.title,
    this.description,
    required this.sequenceOrder,
  });

  final int id;
  final String title;
  final String? description;
  final int sequenceOrder;

  factory Act.fromJson(Map<String, dynamic> json) => Act(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        sequenceOrder: json['sequenceOrder'] as int,
      );
}

class StoryCharacter {
  StoryCharacter({
    required this.id,
    required this.name,
    required this.roleType,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String roleType;
  final String? description;
  final String? imageUrl;

  factory StoryCharacter.fromJson(Map<String, dynamic> json) => StoryCharacter(
        id: json['id'] as int,
        name: json['name'] as String,
        roleType: json['roleType'] as String? ?? 'SUPPORT',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

class StoryLocation {
  StoryLocation({
    required this.id,
    required this.name,
    required this.settingType,
    required this.timeOfDay,
    this.notes,
  });

  final int id;
  final String name;
  final String settingType;
  final String timeOfDay;
  final String? notes;

  factory StoryLocation.fromJson(Map<String, dynamic> json) => StoryLocation(
        id: json['id'] as int,
        name: json['name'] as String,
        settingType: json['settingType'] as String? ?? 'INT',
        timeOfDay: json['timeOfDay'] as String? ?? 'DAY',
        notes: json['notes'] as String?,
      );
}

class SceneCharacter {
  SceneCharacter({
    required this.id,
    required this.name,
    required this.roleType,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String roleType;
  final String? imageUrl;

  factory SceneCharacter.fromJson(Map<String, dynamic> json) => SceneCharacter(
        id: json['id'] as int,
        name: json['name'] as String,
        roleType: json['roleType'] as String? ?? 'SUPPORT',
        imageUrl: json['imageUrl'] as String?,
      );
}

class Scene {
  Scene({
    required this.id,
    required this.actId,
    required this.actTitle,
    required this.locationId,
    required this.locationName,
    required this.settingType,
    required this.timeOfDay,
    required this.sceneNumber,
    this.title,
    required this.summary,
    required this.status,
    this.estimatedMinutes,
    required this.characters,
  });

  final int id;
  final int actId;
  final String actTitle;
  final int locationId;
  final String locationName;
  final String settingType;
  final String timeOfDay;
  final int sceneNumber;
  final String? title;
  final String summary;
  final String status;
  final int? estimatedMinutes;
  final List<SceneCharacter> characters;

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
        id: json['id'] as int,
        actId: json['actId'] as int,
        actTitle: json['actTitle'] as String? ?? '',
        locationId: json['locationId'] as int,
        locationName: json['locationName'] as String? ?? '',
        settingType: json['settingType'] as String? ?? 'INT',
        timeOfDay: json['timeOfDay'] as String? ?? 'DAY',
        sceneNumber: json['sceneNumber'] as int,
        title: json['title'] as String?,
        summary: json['summary'] as String? ?? '',
        status: json['status'] as String? ?? 'TODO',
        estimatedMinutes: json['estimatedMinutes'] as int?,
        characters: ((json['characters'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(SceneCharacter.fromJson)
            .toList(),
      );
}

class PlannerGroup {
  PlannerGroup({
    required this.location,
    required this.sceneCount,
    required this.totalEstimatedMinutes,
    required this.scenes,
  });

  final StoryLocation location;
  final int sceneCount;
  final int totalEstimatedMinutes;
  final List<Scene> scenes;

  factory PlannerGroup.fromJson(Map<String, dynamic> json) => PlannerGroup(
        location:
            StoryLocation.fromJson(json['location'] as Map<String, dynamic>),
        sceneCount: json['sceneCount'] as int? ?? 0,
        totalEstimatedMinutes: json['totalEstimatedMinutes'] as int? ?? 0,
        scenes: ((json['scenes'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Scene.fromJson)
            .toList(),
      );
}

class AnalyticsSummary extends Dashboard {
  AnalyticsSummary({
    required super.totalActs,
    required super.totalCharacters,
    required super.totalLocations,
    required super.totalScenes,
    required super.todoScenes,
    required super.inProgressScenes,
    required super.doneScenes,
    required super.progressPercent,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) =>
      AnalyticsSummary(
        totalActs: json['totalActs'] as int? ?? 0,
        totalCharacters: json['totalCharacters'] as int? ?? 0,
        totalLocations: json['totalLocations'] as int? ?? 0,
        totalScenes: json['totalScenes'] as int? ?? 0,
        todoScenes: json['todoScenes'] as int? ?? 0,
        inProgressScenes: json['inProgressScenes'] as int? ?? 0,
        doneScenes: json['doneScenes'] as int? ?? 0,
        progressPercent: (json['progressPercent'] as num? ?? 0).toDouble(),
      );
}

class CharacterFrequency {
  CharacterFrequency({
    required this.characterId,
    required this.name,
    required this.sceneCount,
  });

  final int characterId;
  final String name;
  final int sceneCount;

  factory CharacterFrequency.fromJson(Map<String, dynamic> json) =>
      CharacterFrequency(
        characterId: json['characterId'] as int,
        name: json['name'] as String,
        sceneCount: json['sceneCount'] as int? ?? 0,
      );
}
