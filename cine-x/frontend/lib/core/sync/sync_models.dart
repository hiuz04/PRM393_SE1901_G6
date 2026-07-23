enum AppUsageMode {
  offlineGuest,
  onlineAccount,
}

enum NetworkStatus {
  online,
  offline,
}

enum EntitySyncStatus {
  localOnly,
  synced,
  pendingCreate,
  pendingUpdate,
  pendingDelete,
  syncing,
  syncFailed,
  conflict,
}

enum SyncOperationType {
  create,
  update,
  delete,
  uploadFile,
}

enum ConflictResolution {
  keepLocal,
  keepRemote,
  merged,
}

extension AppUsageModeCodec on AppUsageMode {
  String get storageValue => switch (this) {
        AppUsageMode.offlineGuest => 'offlineGuest',
        AppUsageMode.onlineAccount => 'onlineAccount',
      };

  static AppUsageMode fromStorage(String? value) {
    return switch (value) {
      'onlineAccount' => AppUsageMode.onlineAccount,
      _ => AppUsageMode.offlineGuest,
    };
  }
}

extension EntitySyncStatusCodec on EntitySyncStatus {
  String get dbValue => switch (this) {
        EntitySyncStatus.localOnly => 'LOCAL_ONLY',
        EntitySyncStatus.synced => 'SYNCED',
        EntitySyncStatus.pendingCreate => 'PENDING_CREATE',
        EntitySyncStatus.pendingUpdate => 'PENDING_UPDATE',
        EntitySyncStatus.pendingDelete => 'PENDING_DELETE',
        EntitySyncStatus.syncing => 'SYNCING',
        EntitySyncStatus.syncFailed => 'SYNC_FAILED',
        EntitySyncStatus.conflict => 'CONFLICT',
      };

  bool get hasPendingChange =>
      this == EntitySyncStatus.pendingCreate ||
      this == EntitySyncStatus.pendingUpdate ||
      this == EntitySyncStatus.pendingDelete ||
      this == EntitySyncStatus.syncing ||
      this == EntitySyncStatus.syncFailed ||
      this == EntitySyncStatus.conflict;

  static EntitySyncStatus fromDb(String? value) {
    return switch (value) {
      'SYNCED' => EntitySyncStatus.synced,
      'PENDING_CREATE' => EntitySyncStatus.pendingCreate,
      'PENDING_UPDATE' => EntitySyncStatus.pendingUpdate,
      'PENDING_DELETE' => EntitySyncStatus.pendingDelete,
      'SYNCING' => EntitySyncStatus.syncing,
      'SYNC_FAILED' => EntitySyncStatus.syncFailed,
      'CONFLICT' => EntitySyncStatus.conflict,
      _ => EntitySyncStatus.localOnly,
    };
  }
}

extension SyncOperationTypeCodec on SyncOperationType {
  String get dbValue => switch (this) {
        SyncOperationType.create => 'CREATE',
        SyncOperationType.update => 'UPDATE',
        SyncOperationType.delete => 'DELETE',
        SyncOperationType.uploadFile => 'UPLOAD_FILE',
      };

  static SyncOperationType fromDb(String value) {
    return switch (value) {
      'CREATE' => SyncOperationType.create,
      'UPDATE' => SyncOperationType.update,
      'DELETE' => SyncOperationType.delete,
      'UPLOAD_FILE' => SyncOperationType.uploadFile,
      _ => throw ArgumentError('Unsupported sync operation: $value'),
    };
  }
}

extension ConflictResolutionCodec on ConflictResolution {
  String get dbValue => switch (this) {
        ConflictResolution.keepLocal => 'KEEP_LOCAL',
        ConflictResolution.keepRemote => 'KEEP_REMOTE',
        ConflictResolution.merged => 'MERGED',
      };
}

class AppSessionState {
  const AppSessionState({
    required this.usageMode,
    required this.networkStatus,
    this.accountId,
    this.accountEmail,
    this.workspaceId,
    this.isSyncing = false,
    this.pendingOperationCount = 0,
    this.conflictCount = 0,
    this.lastSyncedAt,
    this.lastSyncError,
  });

  final AppUsageMode usageMode;
  final NetworkStatus networkStatus;
  final String? accountId;
  final String? accountEmail;
  final String? workspaceId;
  final bool isSyncing;
  final int pendingOperationCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;
  final String? lastSyncError;

  bool get isOfflineGuest => usageMode == AppUsageMode.offlineGuest;
  bool get isOnlineAccount => usageMode == AppUsageMode.onlineAccount;
}

class SyncSummary {
  const SyncSummary({
    this.pendingCreates = 0,
    this.pendingUpdates = 0,
    this.pendingDeletes = 0,
    this.pendingUploads = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  final int pendingCreates;
  final int pendingUpdates;
  final int pendingDeletes;
  final int pendingUploads;
  final int failed;
  final int conflicts;
  final DateTime? lastSyncedAt;
  final String? lastError;

  int get pendingTotal =>
      pendingCreates + pendingUpdates + pendingDeletes + pendingUploads;
}
