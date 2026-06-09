import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'database_constants.dart';

class DatabaseHelper {
  static Database? _database;

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, DatabaseConstants.dbName);
    return openDatabase(
      path,
      version: DatabaseConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableDiaryEntries} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colTitle} TEXT DEFAULT '无标题',
        ${DatabaseConstants.colContent} TEXT NOT NULL,
        ${DatabaseConstants.colMood} TEXT DEFAULT '',
        ${DatabaseConstants.colMoodIntensity} INTEGER DEFAULT 3,
        ${DatabaseConstants.colMoodNote} TEXT DEFAULT '',
        ${DatabaseConstants.colMoodLabel} TEXT DEFAULT '',
        ${DatabaseConstants.colWordCount} INTEGER DEFAULT 0,
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL DEFAULT (datetime('now','localtime')),
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL DEFAULT (datetime('now','localtime')),
        ${DatabaseConstants.colIsLocked} INTEGER DEFAULT 0,
        ${DatabaseConstants.colPinHash} TEXT DEFAULT '',
        ${DatabaseConstants.colTags} TEXT DEFAULT '[]',
        ${DatabaseConstants.colImages} TEXT DEFAULT '[]',
        ${DatabaseConstants.colAudios} TEXT DEFAULT '[]',
        ${DatabaseConstants.colStickers} TEXT DEFAULT '[]'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_created_at ON ${DatabaseConstants.tableDiaryEntries}(${DatabaseConstants.colCreatedAt} DESC)',
    );
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableAchievements} (
        id TEXT PRIMARY KEY,
        unlocked_at TEXT,
        is_read INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colIsLocked} INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colPinHash} TEXT DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colTags} TEXT DEFAULT '[]'",
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colImages} TEXT DEFAULT '[]'",
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colAudios} TEXT DEFAULT '[]'",
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colMoodIntensity} INTEGER DEFAULT 3",
      );
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colMoodNote} TEXT DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colMoodLabel} TEXT DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDiaryEntries} ADD COLUMN ${DatabaseConstants.colStickers} TEXT DEFAULT '[]'",
      );
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableAchievements} (
          id TEXT PRIMARY KEY,
          unlocked_at TEXT,
          is_read INTEGER DEFAULT 0
        )
      ''');
    }
    // 修复旧版本迁移中双引号导致的 NULL 默认值问题
    if (oldVersion < 8) {
      final table = DatabaseConstants.tableDiaryEntries;
      await db.execute("UPDATE $table SET ${DatabaseConstants.colTags} = '[]' WHERE ${DatabaseConstants.colTags} IS NULL");
      await db.execute("UPDATE $table SET ${DatabaseConstants.colImages} = '[]' WHERE ${DatabaseConstants.colImages} IS NULL");
      await db.execute("UPDATE $table SET ${DatabaseConstants.colAudios} = '[]' WHERE ${DatabaseConstants.colAudios} IS NULL");
      await db.execute("UPDATE $table SET ${DatabaseConstants.colStickers} = '[]' WHERE ${DatabaseConstants.colStickers} IS NULL");
      await db.execute("UPDATE $table SET ${DatabaseConstants.colPinHash} = '' WHERE ${DatabaseConstants.colPinHash} IS NULL");
      await db.execute("UPDATE $table SET ${DatabaseConstants.colMoodNote} = '' WHERE ${DatabaseConstants.colMoodNote} IS NULL");
      await db.execute("UPDATE $table SET ${DatabaseConstants.colMoodLabel} = '' WHERE ${DatabaseConstants.colMoodLabel} IS NULL");
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
