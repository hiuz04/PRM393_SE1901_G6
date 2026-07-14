import 'package:flutter/foundation.dart';

import '../data/repositories/act_repository.dart';
import '../models/act.dart';

class ActProvider extends ChangeNotifier {
  ActProvider({ActRepository? repository})
    : _repository = repository ?? ActRepository();

  final ActRepository _repository;

  List<Act> _acts = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentProjectId;
  bool _isDisposed = false;

  List<Act> get acts => List.unmodifiable(_acts);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadActs(int projectId) async {
    _currentProjectId = projectId;
    _setLoading(true);

    try {
      _acts = await _repository.getActsByProject(projectId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Unable to load acts: $error';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addAct(Act act) async {
    return _mutateActs(
      () async {
        await _repository.insertAct(act);
      },
      act.projectId,
      'Unable to create act',
    );
  }

  Future<bool> updateAct(Act act) async {
    return _mutateActs(
      () async {
        await _repository.updateAct(act);
      },
      act.projectId,
      'Unable to update act',
    );
  }

  Future<bool> deleteAct(int id) async {
    final projectId = _currentProjectId;
    if (projectId == null) {
      _errorMessage = 'No project selected.';
      _notifyListeners();
      return false;
    }

    return _mutateActs(
      () async {
        await _repository.deleteAct(id);
      },
      projectId,
      'Unable to delete act',
    );
  }

  Future<int> getNextSequenceOrder(int projectId) async {
    try {
      return await _repository.getNextSequenceOrder(projectId);
    } catch (error) {
      _errorMessage = 'Unable to calculate next act order: $error';
      _notifyListeners();
      return 1;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<bool> _mutateActs(
    Future<void> Function() action,
    int projectId,
    String failureMessage,
  ) async {
    _currentProjectId = projectId;
    _setLoading(true);

    try {
      await action();
      _acts = await _repository.getActsByProject(projectId);
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

  void _notifyListeners() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }
}
