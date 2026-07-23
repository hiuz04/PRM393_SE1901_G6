import 'package:flutter/foundation.dart';

import '../models/cinex_models.dart';
import '../repositories/cinex_repository.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectProvider.empty();

  CineXRepository? _repository;
  final List<Project> _projects = [];
  bool isLoading = false;
  String? errorMessage;

  List<Project> get projects => List.unmodifiable(_projects);
  bool get loading => isLoading;
  String? get error => errorMessage;

  void attach(CineXRepository repository) {
    _repository = repository;
  }

  Future<void> load({String? search}) async {
    final repository = _repository;
    if (repository == null) return;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final items = await repository.projects(search: search);
      _projects
        ..clear()
        ..addAll(items);
    } catch (ex) {
      errorMessage = ex.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create(
    String title, {
    String? genre,
    String? description,
    String? posterUrl,
    DateTime? startDate,
    DateTime? endDate,
    int maxShootingMinutesPerDay = 480,
  }) async {
    final repository = _repository;
    if (repository == null) return false;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await repository.createProject({
        'title': title,
        'genre': genre,
        'description': description,
        'posterUrl': posterUrl,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'maxShootingMinutesPerDay': maxShootingMinutesPerDay,
      });
      await load();
      return true;
    } catch (ex) {
      errorMessage = ex.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> delete(Project project) async {
    await _repository!.deleteProject(project.id);
    await load();
  }
}
