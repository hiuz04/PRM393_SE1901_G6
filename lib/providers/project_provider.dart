import 'package:flutter/foundation.dart';

import '../data/repositories/project_repository.dart';
import '../models/dashboard_summary.dart';
import '../models/project.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectProvider({ProjectRepository? repository})
    : _repository = repository ?? ProjectRepository();

  final ProjectRepository _repository;

  List<Project> _projects = [];
  Project? _selectedProject;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<Project> get projects => List.unmodifiable(_projects);
  Project? get selectedProject => _selectedProject;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadProjects() async {
    _setLoading(true);

    try {
      _projects = await _repository.getAllProjects();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Unable to load projects: $error';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadProject(int id) async {
    _setLoading(true);

    try {
      _selectedProject = await _repository.getProjectById(id);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Unable to load project: $error';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addProject(Project project) async {
    return _mutateProjects(() async {
      await _repository.insertProject(project);
    }, 'Unable to create project');
  }

  Future<bool> updateProject(Project project) async {
    return _mutateProjects(() async {
      await _repository.updateProject(project);
    }, 'Unable to update project');
  }

  Future<bool> deleteProject(int id) async {
    return _mutateProjects(() async {
      await _repository.deleteProject(id);
      if (_selectedProject?.id == id) {
        _selectedProject = null;
      }
    }, 'Unable to delete project');
  }

  Future<DashboardSummary> getDashboardSummary(int projectId) {
    return _repository.getDashboardSummary(projectId);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<bool> _mutateProjects(
    Future<void> Function() action,
    String failureMessage,
  ) async {
    _setLoading(true);

    try {
      await action();
      _projects = await _repository.getAllProjects();

      final selectedId = _selectedProject?.id;
      if (selectedId != null) {
        _selectedProject = await _repository.getProjectById(selectedId);
      }

      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = '$failureMessage: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isDisposed) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }
}
