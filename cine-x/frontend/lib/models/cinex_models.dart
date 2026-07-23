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

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : DateTime.tryParse(text);
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

bool _boolFromInt(Object? value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return value.toString() == '1' || value.toString().toLowerCase() == 'true';
}

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.systemRole = 'USER',
    this.isActive = true,
    this.createdAt,
  });

  final int id;
  final String email;
  final String fullName;
  final String systemRole;
  final bool isActive;
  final DateTime? createdAt;

  String get displayName => fullName;

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int,
        email: map['email'] as String,
        fullName: (map['full_name'] ?? map['displayName']) as String,
        systemRole: map['systemRole'] as String? ?? 'USER',
        isActive: _boolFromInt(map['is_active'], defaultValue: true),
        createdAt: _dateTimeOrNull(map['created_at']),
      );

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: (json['fullName'] ?? json['displayName']) as String,
        systemRole: json['systemRole'] as String? ?? 'USER',
        isActive: json['isActive'] as bool? ?? true,
        createdAt: _dateTimeOrNull(json['createdAt']),
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
        accessToken: json['accessToken'] as String? ?? '',
        tokenType: json['tokenType'] as String? ?? 'Local',
        expiresIn: json['expiresIn'] as int? ?? 0,
        user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

class Project {
  Project({
    required this.id,
    required int ownerId,
    required this.title,
    this.genre,
    this.description,
    this.startDate,
    this.endDate,
    this.maxShootingMinutesPerDay = 480,
    this.posterUrl,
    this.deleted = false,
    this.progressPercent = 0,
    this.createdAt,
    this.updatedAt,
  }) : ownerUserId = ownerId;

  final int id;
  final int ownerUserId;
  final String title;
  final String? genre;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final int maxShootingMinutesPerDay;
  final String? posterUrl;
  final bool deleted;
  final double progressPercent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get ownerId => ownerUserId;
  String get status => deleted ? 'ARCHIVED' : 'ACTIVE';

  factory Project.fromMap(
    Map<String, Object?> map, {
    double progressPercent = 0,
  }) =>
      Project(
        id: map['id'] as int,
        ownerId: map['owner_user_id'] as int,
        title: map['title'] as String,
        genre: _stringOrNull(map['genre']),
        description: _stringOrNull(map['description']),
        startDate: _dateTimeOrNull(map['start_date']),
        endDate: _dateTimeOrNull(map['end_date']),
        maxShootingMinutesPerDay:
            map['max_shooting_minutes_per_day'] as int? ?? 480,
        posterUrl: _stringOrNull(map['poster_url']),
        progressPercent: progressPercent,
        createdAt: _dateTimeOrNull(map['created_at']),
        updatedAt: _dateTimeOrNull(map['updated_at']),
      );

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as int,
        ownerId: (json['ownerId'] ?? json['ownerUserId']) as int,
        title: json['title'] as String,
        genre: json['genre'] as String?,
        description: json['description'] as String?,
        startDate: _dateTimeOrNull(json['startDate']),
        endDate: _dateTimeOrNull(json['endDate']),
        maxShootingMinutesPerDay:
            json['maxShootingMinutesPerDay'] as int? ?? 480,
        posterUrl: json['posterUrl'] as String?,
        deleted: json['deleted'] as bool? ?? false,
        progressPercent: (json['progressPercent'] as num? ?? 0).toDouble(),
        createdAt: _dateTimeOrNull(json['createdAt']),
        updatedAt: _dateTimeOrNull(json['updatedAt']),
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
    this.totalResources = 0,
    this.totalShootingDays = 0,
  });

  final int totalActs;
  final int totalCharacters;
  final int totalLocations;
  final int totalScenes;
  final int todoScenes;
  final int inProgressScenes;
  final int doneScenes;
  final double progressPercent;
  final int totalResources;
  final int totalShootingDays;

  factory Dashboard.fromJson(Map<String, dynamic> json) => Dashboard(
        totalActs: json['totalActs'] as int? ?? 0,
        totalCharacters: json['totalCharacters'] as int? ?? 0,
        totalLocations: json['totalLocations'] as int? ?? 0,
        totalScenes: json['totalScenes'] as int? ?? 0,
        todoScenes: json['todoScenes'] as int? ?? 0,
        inProgressScenes: json['inProgressScenes'] as int? ?? 0,
        doneScenes: json['doneScenes'] as int? ?? 0,
        progressPercent: (json['progressPercent'] as num? ?? 0).toDouble(),
        totalResources: json['totalResources'] as int? ?? 0,
        totalShootingDays: json['totalShootingDays'] as int? ?? 0,
      );
}

class ProjectMember {
  ProjectMember({
    required this.projectId,
    required this.userId,
    required this.role,
    this.fullName,
    this.email,
  });

  final int projectId;
  final int userId;
  final String role;
  final String? fullName;
  final String? email;

  factory ProjectMember.fromMap(Map<String, Object?> map) => ProjectMember(
        projectId: map['project_id'] as int,
        userId: map['user_id'] as int,
        role: map['role'] as String,
        fullName: _stringOrNull(map['full_name']),
        email: _stringOrNull(map['email']),
      );
}

class Act {
  Act({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.sequenceOrder,
  });

  final int id;
  final int projectId;
  final String title;
  final String? description;
  final int sequenceOrder;

  factory Act.fromMap(Map<String, Object?> map) => Act(
        id: map['id'] as int,
        projectId: map['project_id'] as int? ?? 0,
        title: map['title'] as String,
        description: _stringOrNull(map['description']),
        sequenceOrder: map['sequence_order'] as int,
      );

  factory Act.fromJson(Map<String, dynamic> json) => Act(
        id: json['id'] as int,
        projectId: json['projectId'] as int? ?? 0,
        title: json['title'] as String,
        description: json['description'] as String?,
        sequenceOrder: json['sequenceOrder'] as int,
      );
}

class StoryCharacter {
  StoryCharacter({
    required this.id,
    required this.projectId,
    required this.name,
    required this.roleType,
    this.psychologicalDescription,
    this.appearanceDescription,
    this.imagePath,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int projectId;
  final String name;
  final String roleType;
  final String? psychologicalDescription;
  final String? appearanceDescription;
  final String? imagePath;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get description => psychologicalDescription;
  String? get imageUrl => imagePath;

  factory StoryCharacter.fromMap(Map<String, Object?> map) => StoryCharacter(
        id: map['id'] as int,
        projectId: map['project_id'] as int? ?? 0,
        name: map['name'] as String,
        roleType: map['role_type'] as String,
        psychologicalDescription:
            _stringOrNull(map['psychological_description']),
        appearanceDescription: _stringOrNull(map['appearance_description']),
        imagePath: _stringOrNull(map['image_path']),
        isArchived: _boolFromInt(map['is_archived']),
        createdAt: _dateTimeOrNull(map['created_at']),
        updatedAt: _dateTimeOrNull(map['updated_at']),
      );

  factory StoryCharacter.fromJson(Map<String, dynamic> json) =>
      StoryCharacter(
        id: json['id'] as int,
        projectId: json['projectId'] as int? ?? 0,
        name: json['name'] as String,
        roleType: json['roleType'] as String? ?? 'SUPPORT',
        psychologicalDescription:
            json['psychologicalDescription'] as String? ??
                json['description'] as String?,
        appearanceDescription: json['appearanceDescription'] as String?,
        imagePath: json['imagePath'] as String? ?? json['imageUrl'] as String?,
        isArchived: json['isArchived'] as bool? ?? false,
      );
}

class StoryLocation {
  StoryLocation({
    required this.id,
    required this.projectId,
    required this.name,
    this.settingType = 'INT',
    this.timeOfDay = 'DAY',
    this.description,
    this.notes,
    this.isArchived = false,
  });

  final int id;
  final int projectId;
  final String name;
  final String settingType;
  final String timeOfDay;
  final String? description;
  final String? notes;
  final bool isArchived;

  factory StoryLocation.fromMap(Map<String, Object?> map) => StoryLocation(
        id: map['id'] as int,
        projectId: map['project_id'] as int? ?? 0,
        name: map['name'] as String,
        settingType: (map['setting_type'] as String?) ?? (map['setting'] as String?) ?? 'INT',
        timeOfDay: (map['time_of_day'] as String?) ?? 'DAY',
        description: _stringOrNull(map['description']),
        notes: _stringOrNull(map['notes']),
        isArchived: _boolFromInt(map['is_archived']),
      );

  factory StoryLocation.fromJson(Map<String, dynamic> json) => StoryLocation(
        id: json['id'] as int,
        projectId: json['projectId'] as int? ?? 0,
        name: json['name'] as String,
        settingType: json['settingType'] as String? ?? json['setting'] as String? ?? 'INT',
        timeOfDay: json['timeOfDay'] as String? ?? 'DAY',
        description: json['description'] as String?,
        notes: json['notes'] as String?,
      );
}

class ShootingLocation {
  ShootingLocation({
    required this.id,
    required this.projectId,
    required this.name,
    required this.address,
    this.provinceCity,
    this.district,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
    this.supportsInterior = true,
    this.supportsExterior = true,
    this.availableFromTime,
    this.availableToTime,
    this.notes,
    this.imagePath,
    this.isActive = true,
  });

  final int id;
  final int projectId;
  final String name;
  final String address;
  final String? provinceCity;
  final String? district;
  final double? latitude;
  final double? longitude;
  final String? contactName;
  final String? contactPhone;
  final bool supportsInterior;
  final bool supportsExterior;
  final String? availableFromTime;
  final String? availableToTime;
  final String? notes;
  final String? imagePath;
  final bool isActive;

  factory ShootingLocation.fromMap(Map<String, Object?> map) =>
      ShootingLocation(
        id: map['id'] as int,
        projectId: map['project_id'] as int? ?? 0,
        name: map['name'] as String,
        address: map['address'] as String,
        provinceCity: _stringOrNull(map['province_city']),
        district: _stringOrNull(map['district']),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        contactName: _stringOrNull(map['contact_name']),
        contactPhone: _stringOrNull(map['contact_phone']),
        supportsInterior:
            _boolFromInt(map['supports_interior'], defaultValue: true),
        supportsExterior:
            _boolFromInt(map['supports_exterior'], defaultValue: true),
        availableFromTime: _stringOrNull(map['available_from_time']),
        availableToTime: _stringOrNull(map['available_to_time']),
        notes: _stringOrNull(map['notes']),
        imagePath: _stringOrNull(map['image_path']),
        isActive: _boolFromInt(map['is_active'], defaultValue: true),
      );
}

class FilmResource {
  FilmResource({
    required this.id,
    required this.projectId,
    required this.name,
    required this.resourceType,
    required this.quantityTotal,
    this.unit,
    this.status,
    this.imagePath,
    this.notes,
    this.isArchived = false,
  });

  final int id;
  final int projectId;
  final String name;
  final String resourceType;
  final int quantityTotal;
  final String? unit;
  final String? status;
  final String? imagePath;
  final String? notes;
  final bool isArchived;

  factory FilmResource.fromMap(Map<String, Object?> map) => FilmResource(
        id: map['id'] as int,
        projectId: map['project_id'] as int? ?? 0,
        name: map['name'] as String,
        resourceType: map['resource_type'] as String,
        quantityTotal: map['quantity_total'] as int,
        unit: _stringOrNull(map['unit']),
        status: _stringOrNull(map['status']),
        imagePath: _stringOrNull(map['image_path']),
        notes: _stringOrNull(map['notes']),
        isArchived: _boolFromInt(map['is_archived']),
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

  factory SceneCharacter.fromMap(Map<String, Object?> map) => SceneCharacter(
        id: map['id'] as int,
        name: map['name'] as String,
        roleType: map['role_type'] as String,
        imageUrl: _stringOrNull(map['image_path']),
      );

  factory SceneCharacter.fromJson(Map<String, dynamic> json) => SceneCharacter(
        id: json['id'] as int,
        name: json['name'] as String,
        roleType: json['roleType'] as String? ?? 'SUPPORT',
        imageUrl: json['imageUrl'] as String?,
      );
}

class SceneResource {
  SceneResource({
    required this.id,
    required this.name,
    required this.resourceType,
    required this.quantityTotal,
    required this.requiredQuantity,
    this.unit,
    this.notes,
  });

  final int id;
  final String name;
  final String resourceType;
  final int quantityTotal;
  final int requiredQuantity;
  final String? unit;
  final String? notes;

  factory SceneResource.fromMap(Map<String, Object?> map) => SceneResource(
        id: map['id'] as int,
        name: map['name'] as String,
        resourceType: map['resource_type'] as String,
        quantityTotal: map['quantity_total'] as int,
        requiredQuantity: map['required_quantity'] as int? ?? 1,
        unit: _stringOrNull(map['unit']),
        notes: _stringOrNull(map['scene_resource_notes']),
      );
}

class Scene {
  Scene({
    required this.id,
    required this.projectId,
    required this.actId,
    required this.actTitle,
    required this.storyLocationId,
    required this.storyLocationName,
    this.plannedShootingLocationId,
    this.plannedShootingLocationName,
    this.plannedShootingLocationAddress,
    this.shootingLocationSupportsInterior = true,
    this.shootingLocationSupportsExterior = true,
    required this.settingType,
    required this.timeOfDay,
    required this.sceneNumber,
    this.title,
    required this.summary,
    required this.writingStatus,
    required this.productionStatus,
    required this.estimatedDurationMinutes,
    required this.priority,
    required this.characters,
    this.resources = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int projectId;
  final int actId;
  final String actTitle;
  final int storyLocationId;
  final String storyLocationName;
  final int? plannedShootingLocationId;
  final String? plannedShootingLocationName;
  final String? plannedShootingLocationAddress;
  final bool shootingLocationSupportsInterior;
  final bool shootingLocationSupportsExterior;
  final String settingType;
  final String timeOfDay;
  final int sceneNumber;
  final String? title;
  final String summary;
  final String writingStatus;
  final String productionStatus;
  final int estimatedDurationMinutes;
  final int priority;
  final List<SceneCharacter> characters;
  final List<SceneResource> resources;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get locationId => storyLocationId;
  String get locationName => storyLocationName;
  String get status => writingStatus;
  int? get estimatedMinutes => estimatedDurationMinutes;
  String get sceneHeading {
    final setting = switch (settingType.toUpperCase()) {
      'INT' => 'INT.',
      'EXT' => 'EXT.',
      _ => settingType.toUpperCase(),
    };
    final time = switch (timeOfDay.toUpperCase()) {
      'DAY' => 'NGÀY',
      'NIGHT' => 'ĐÊM',
      _ => timeOfDay.toUpperCase(),
    };
    return 'CẢNH $sceneNumber: $setting ${storyLocationName.toUpperCase()} - $time';
  }

  String get shootingLocationLabel {
    final name = plannedShootingLocationName;
    if (name == null || name.isEmpty) return 'Chưa gán địa điểm quay';
    final address = plannedShootingLocationAddress;
    if (address == null || address.isEmpty) return name;
    return '$name, $address';
  }

  factory Scene.fromMap(
    Map<String, Object?> map, {
    List<SceneCharacter> characters = const [],
    List<SceneResource> resources = const [],
  }) =>
      Scene(
        id: map['id'] as int,
        projectId: map['project_id'] as int? ?? 0,
        actId: map['act_id'] as int,
        actTitle: map['act_title'] as String? ?? '',
        storyLocationId: map['story_location_id'] as int,
        storyLocationName: map['story_location_name'] as String? ?? '',
        plannedShootingLocationId:
            map['planned_shooting_location_id'] as int?,
        plannedShootingLocationName:
            _stringOrNull(map['shooting_location_name']),
        plannedShootingLocationAddress:
            _stringOrNull(map['shooting_location_address']),
        shootingLocationSupportsInterior: _boolFromInt(
          map['supports_interior'],
          defaultValue: true,
        ),
        shootingLocationSupportsExterior: _boolFromInt(
          map['supports_exterior'],
          defaultValue: true,
        ),
        sceneNumber: map['scene_number'] as int,
        title: _stringOrNull(map['title']),
        summary: map['summary'] as String? ?? '',
        settingType: map['setting_type'] as String,
        timeOfDay: map['time_of_day'] as String,
        estimatedDurationMinutes:
            map['estimated_duration_minutes'] as int? ?? 1,
        priority: map['priority'] as int? ?? 3,
        writingStatus: map['writing_status'] as String? ?? 'TODO',
        productionStatus:
            map['production_status'] as String? ?? 'NOT_READY',
        characters: characters,
        resources: resources,
        createdAt: _dateTimeOrNull(map['created_at']),
        updatedAt: _dateTimeOrNull(map['updated_at']),
      );

  factory Scene.fromJson(Map<String, dynamic> json) => Scene(
        id: json['id'] as int,
        projectId: json['projectId'] as int? ?? 0,
        actId: json['actId'] as int,
        actTitle: json['actTitle'] as String? ?? '',
        storyLocationId: json['storyLocationId'] as int? ??
            json['locationId'] as int? ??
            0,
        storyLocationName: json['storyLocationName'] as String? ??
            json['locationName'] as String? ??
            '',
        plannedShootingLocationId: json['plannedShootingLocationId'] as int?,
        plannedShootingLocationName:
            json['plannedShootingLocationName'] as String?,
        plannedShootingLocationAddress:
            json['plannedShootingLocationAddress'] as String?,
        settingType: json['settingType'] as String? ?? 'INT',
        timeOfDay: json['timeOfDay'] as String? ?? 'DAY',
        sceneNumber: json['sceneNumber'] as int,
        title: json['title'] as String?,
        summary: json['summary'] as String? ?? '',
        writingStatus: json['writingStatus'] as String? ??
            json['status'] as String? ??
            'TODO',
        productionStatus: json['productionStatus'] as String? ?? 'NOT_READY',
        estimatedDurationMinutes: json['estimatedDurationMinutes'] as int? ??
            json['estimatedMinutes'] as int? ??
            1,
        priority: json['priority'] as int? ?? 3,
        characters: ((json['characters'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(SceneCharacter.fromJson)
            .toList(),
      );
}

class PlannerGroup {
  PlannerGroup({
    required this.locationName,
    required this.sceneCount,
    required this.totalEstimatedMinutes,
    required this.scenes,
  });

  final String locationName;
  final int sceneCount;
  final int totalEstimatedMinutes;
  final List<Scene> scenes;

  StoryLocation get location => StoryLocation(
        id: scenes.isEmpty ? 0 : scenes.first.storyLocationId,
        projectId: scenes.isEmpty ? 0 : scenes.first.projectId,
        name: locationName,
      );

  factory PlannerGroup.fromJson(Map<String, dynamic> json) => PlannerGroup(
        locationName:
            (json['location'] as Map<String, dynamic>?)?['name'] as String? ??
                json['locationName'] as String? ??
                '',
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
    super.totalResources,
    super.totalShootingDays,
  });

  factory AnalyticsSummary.fromDashboard(Dashboard dashboard) =>
      AnalyticsSummary(
        totalActs: dashboard.totalActs,
        totalCharacters: dashboard.totalCharacters,
        totalLocations: dashboard.totalLocations,
        totalScenes: dashboard.totalScenes,
        todoScenes: dashboard.todoScenes,
        inProgressScenes: dashboard.inProgressScenes,
        doneScenes: dashboard.doneScenes,
        progressPercent: dashboard.progressPercent,
        totalResources: dashboard.totalResources,
        totalShootingDays: dashboard.totalShootingDays,
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

  factory CharacterFrequency.fromMap(Map<String, Object?> map) =>
      CharacterFrequency(
        characterId: map['character_id'] as int,
        name: map['name'] as String,
        sceneCount: map['scene_count'] as int? ?? 0,
      );

  factory CharacterFrequency.fromJson(Map<String, dynamic> json) =>
      CharacterFrequency(
        characterId: json['characterId'] as int,
        name: json['name'] as String,
        sceneCount: json['sceneCount'] as int? ?? 0,
      );
}

class ShootingDayScene {
  ShootingDayScene({
    required this.shootingDayId,
    required this.scene,
    required this.sequenceOrder,
    this.plannedStartTime,
    this.plannedEndTime,
    this.notes,
  });

  final int shootingDayId;
  final Scene scene;
  final int sequenceOrder;
  final String? plannedStartTime;
  final String? plannedEndTime;
  final String? notes;

  factory ShootingDayScene.fromMap(
    Map<String, Object?> map, {
    required Scene scene,
  }) =>
      ShootingDayScene(
        shootingDayId: map['shooting_day_id'] as int,
        scene: scene,
        sequenceOrder: map['sequence_order'] as int,
        plannedStartTime: _stringOrNull(map['planned_start_time']),
        plannedEndTime: _stringOrNull(map['planned_end_time']),
        notes: _stringOrNull(map['notes']),
      );
}

class ShootingDay {
  ShootingDay({
    required this.id,
    required this.projectId,
    required this.shootingDate,
    required this.title,
    required this.status,
    required this.maxMinutes,
    this.notes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.scenes = const [],
  });

  final int id;
  final int projectId;
  final DateTime shootingDate;
  final String title;
  final String status;
  final int maxMinutes;
  final String? notes;
  final int? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShootingDayScene> scenes;

  int get totalMinutes => scenes.fold(
        0,
        (sum, item) => sum + item.scene.estimatedDurationMinutes,
      );

  bool get isActive => status != 'CANCELLED' && status != 'COMPLETED';

  factory ShootingDay.fromMap(
    Map<String, Object?> map, {
    List<ShootingDayScene> scenes = const [],
  }) =>
      ShootingDay(
        id: map['id'] as int,
        projectId: map['project_id'] as int,
        shootingDate: DateTime.parse(map['shooting_date'] as String),
        title: map['title'] as String,
        status: map['status'] as String,
        maxMinutes: map['max_minutes'] as int,
        notes: _stringOrNull(map['notes']),
        createdBy: map['created_by'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        scenes: scenes,
      );
}
