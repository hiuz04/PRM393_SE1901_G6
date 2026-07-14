import 'package:flutter/foundation.dart';

import '../data/repositories/project_repository.dart';
import '../models/dashboard_summary.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({ProjectRepository? repository})
    : _repository = repository ?? ProjectRepository();

  final ProjectRepository _repository;

  DashboardSummary? _summary;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  DashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard(int projectId) async {
    _setLoading(true);

    try {
      _summary = await _repository.getDashboardSummary(projectId);
      _errorMessage = null;
    } catch (error) {
      _summary = DashboardSummary.empty();
      _errorMessage = 'Unable to load dashboard: $error';
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _setLoading(bool value) {
    if (_isDisposed) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }
}
