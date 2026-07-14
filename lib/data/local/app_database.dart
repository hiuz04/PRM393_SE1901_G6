import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _databaseName = 'cine_x.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    final currentDatabase = _database;
    if (currentDatabase != null) {
      return currentDatabase;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDatabase,
    );
  }

  Future<void> close() async {
    final currentDatabase = _database;
    if (currentDatabase == null) {
      return;
    }

    await currentDatabase.close();
    _database = null;
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        genre TEXT,
        description TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE Acts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        sequence_order INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES Projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Characters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        role_type TEXT,
        description TEXT,
        image_path TEXT,
        FOREIGN KEY(project_id) REFERENCES Projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Locations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        setting TEXT,
        time_of_day TEXT,
        notes TEXT,
        FOREIGN KEY(project_id) REFERENCES Projects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Scenes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        act_id INTEGER NOT NULL,
        location_id INTEGER,
        scene_number INTEGER,
        summary TEXT,
        status TEXT DEFAULT 'TODO',
        FOREIGN KEY(act_id) REFERENCES Acts(id) ON DELETE CASCADE,
        FOREIGN KEY(location_id) REFERENCES Locations(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Scene_Characters (
        scene_id INTEGER NOT NULL,
        character_id INTEGER NOT NULL,
        PRIMARY KEY(scene_id, character_id),
        FOREIGN KEY(scene_id) REFERENCES Scenes(id) ON DELETE CASCADE,
        FOREIGN KEY(character_id) REFERENCES Characters(id) ON DELETE CASCADE
      )
    ''');
  }
}
