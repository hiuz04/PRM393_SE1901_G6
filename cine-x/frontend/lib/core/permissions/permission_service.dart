import 'package:sqflite/sqflite.dart';

enum ProjectPermission {
  manageProject,
  deleteProject,
  manageMembers,
  manageStory,
  manageCharacters,
  manageStoryLocations,
  manageShootingLocations,
  manageResources,
  viewSchedule,
  manageSchedule,
  confirmSchedule,
  exportProject,
}

class AuthorizationException implements Exception {
  AuthorizationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PermissionService {
  PermissionService(this._db);

  final Database _db;

  static const ownerPermissions = ProjectPermission.values;

  static const screenwriterPermissions = {
    ProjectPermission.manageStory,
    ProjectPermission.manageCharacters,
    ProjectPermission.manageStoryLocations,
    ProjectPermission.viewSchedule,
    ProjectPermission.exportProject,
  };

  static const producerPermissions = {
    ProjectPermission.manageShootingLocations,
    ProjectPermission.manageResources,
    ProjectPermission.viewSchedule,
    ProjectPermission.manageSchedule,
    ProjectPermission.confirmSchedule,
    ProjectPermission.exportProject,
  };

  static Set<ProjectPermission> permissionsForRoles(Iterable<String> roles) {
    final permissions = <ProjectPermission>{};
    for (final role in roles) {
      switch (role) {
        case 'LOCAL_OWNER':
        case 'OWNER':
          permissions.addAll(ownerPermissions);
        case 'SCREENWRITER':
          permissions.addAll(screenwriterPermissions);
        case 'PRODUCER':
          permissions.addAll(producerPermissions);
      }
    }
    return permissions;
  }

  Future<List<String>> rolesForUser(int projectId, int userId) async {
    final rows = await _db.query(
      'project_members',
      columns: ['role'],
      where: 'project_id = ? AND user_id = ?',
      whereArgs: [projectId, userId],
    );
    return rows.map((row) => row['role'] as String).toList();
  }

  Future<Set<ProjectPermission>> permissionsForUser(
    int projectId,
    int userId,
  ) async {
    return permissionsForRoles(await rolesForUser(projectId, userId));
  }

  Future<bool> can(
    int projectId,
    int userId,
    ProjectPermission permission,
  ) async {
    final permissions = await permissionsForUser(projectId, userId);
    return permissions.contains(permission);
  }

  Future<void> require(
    int projectId,
    int userId,
    ProjectPermission permission,
  ) async {
    if (!await can(projectId, userId, permission)) {
      throw AuthorizationException(
        'Bạn không có quyền thực hiện thao tác này trong dự án.',
      );
    }
  }
}
