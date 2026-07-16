import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/models/cinex_models.dart';
import '../../data/repositories/cinex_repository.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectProvider.empty();

  CineXRepository? _repository;
  List<Project> projects = [];
  bool loading = false;
  String? error;

  void attach(CineXRepository repository) {
    _repository = repository;
  }

  Future<void> load({String? search}) async {
    if (_repository == null) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      projects = await _repository!.projects(search: search);
    } on AppException catch (ex) {
      error = ex.message;
    } catch (_) {
      error = 'Unable to load projects';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create(
    String title, {
    String? genre,
    String? description,
    String? posterUrl,
  }) async {
    try {
      await _repository!.createProject({
        'title': title,
        'genre': genre,
        'description': description,
        'posterUrl': posterUrl,
        'status': 'ACTIVE',
      });
      await load();
      return true;
    } on AppException catch (ex) {
      error = ex.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> delete(Project project) async {
    await _repository!.deleteProject(project.id);
    await load();
  }
}
