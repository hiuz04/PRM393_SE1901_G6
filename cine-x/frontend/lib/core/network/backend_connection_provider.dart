import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

enum BackendConnectionStatus { idle, checking, online, offline }

class BackendConnectionProvider extends ChangeNotifier {
  BackendConnectionProvider.empty();
  BackendConnectionProvider.local(this._database);

  Database? _database;
  BackendConnectionStatus status = BackendConnectionStatus.idle;
  String? error;
  DateTime? checkedAt;

  bool get checking => status == BackendConnectionStatus.checking;
  bool get online => status == BackendConnectionStatus.online;

  void attach(Database database) {
    _database = database;
  }

  Future<void> check() async {
    final database = _database;
    if (database == null) {
      return;
    }

    status = BackendConnectionStatus.checking;
    error = null;
    notifyListeners();

    try {
      await database.rawQuery('SELECT 1');
      status = BackendConnectionStatus.online;
    } catch (_) {
      status = BackendConnectionStatus.offline;
      error = 'Không thể mở cơ sở dữ liệu SQLite cục bộ';
    } finally {
      checkedAt = DateTime.now();
      notifyListeners();
    }
  }
}
