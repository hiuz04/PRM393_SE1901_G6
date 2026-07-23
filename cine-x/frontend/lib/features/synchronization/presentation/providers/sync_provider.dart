import 'package:flutter/foundation.dart';

import '../../../../core/sync/sync_coordinator.dart';
import '../../../../core/sync/sync_models.dart';

class SyncProvider extends ChangeNotifier {
  SyncProvider.empty();

  SyncCoordinator? _coordinator;
  SyncSummary summary = const SyncSummary();
  bool loading = false;
  String? error;

  bool get hasPending => summary.pendingTotal > 0;
  bool get hasConflicts => summary.conflicts > 0;

  void attach(SyncCoordinator coordinator) {
    _coordinator = coordinator;
  }

  Future<void> refresh() async {
    final coordinator = _coordinator;
    if (coordinator == null) return;
    summary = await coordinator.summary();
    notifyListeners();
  }

  Future<List<SyncDetailItem>> details(SyncDetailKind kind) async {
    final coordinator = _coordinator;
    if (coordinator == null) return const [];
    return coordinator.details(kind);
  }

  Future<List<SyncProjectOption>> localProjects() async {
    final coordinator = _coordinator;
    if (coordinator == null) return const [];
    return coordinator.localProjects();
  }

  Future<bool> syncNow() async {
    final coordinator = _coordinator;
    if (coordinator == null || loading) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await coordinator.syncNow();
      summary = await coordinator.summary();
      return true;
    } catch (ex) {
      error = ex.toString().replaceFirst('Exception: ', '');
      summary = await coordinator.summary();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> syncProject(int projectId) async {
    final coordinator = _coordinator;
    if (coordinator == null || loading) return false;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await coordinator.syncProjectToServer(projectId);
      summary = await coordinator.summary();
      return true;
    } catch (ex) {
      error = ex.toString().replaceFirst('Exception: ', '');
      summary = await coordinator.summary();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
