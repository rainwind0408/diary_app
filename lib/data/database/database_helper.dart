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
        ${DatabaseConstants.colStickers} TEXT DEFAULT '[]',
        ${DatabaseConstants.colWeather} TEXT DEFAULT '',
        ${DatabaseConstants.colLocation} TEXT DEFAULT ''
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
    await _createChatTables(db);
  }

  /// 创建 AI 助手会话相关表（幂等，onCreate 与 onUpgrade 共用）
  Future<void> _createChatTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableChatSessions} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colTitle} TEXT NOT NULL DEFAULT '新会话',
        ${DatabaseConstants.colProviderId} TEXT DEFAULT '',
        ${DatabaseConstants.colModel} TEXT DEFAULT '',
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colUpdatedAt} TEXT NOT NULL,
        ${DatabaseConstants.colIsPinned} INTEGER DEFAULT 0,
        ${DatabaseConstants.colMessageCount} INTEGER DEFAULT 0,
        ${DatabaseConstants.colLastMessage} TEXT DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableChatMessages} (
        ${DatabaseConstants.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DatabaseConstants.colSessionId} INTEGER NOT NULL,
        ${DatabaseConstants.colRole} TEXT NOT NULL,
        ${DatabaseConstants.colContent} TEXT DEFAULT '',
        ${DatabaseConstants.colToolCalls} TEXT DEFAULT '[]',
        ${DatabaseConstants.colToolCallId} TEXT DEFAULT '',
        ${DatabaseConstants.colToolName} TEXT DEFAULT '',
        ${DatabaseConstants.colAttachments} TEXT DEFAULT '[]',
        ${DatabaseConstants.colStatus} TEXT DEFAULT 'sent',
        ${DatabaseConstants.colReasoning} TEXT DEFAULT '',
        ${DatabaseConstants.colCreatedAt} TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_msg_session '
      'ON ${DatabaseConstants.tableChatMessages}('
      '${DatabaseConstants.colSessionId}, ${DatabaseConstants.colCreatedAt})',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_chat_session_updated '
      'ON ${DatabaseConstants.tableChatSessions}('
      '${DatabaseConstants.colIsPinned} DESC, ${DatabaseConstants.colUpdatedAt} DESC)',
    );
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
    // v9：AI 助手会话与消息表
    if (oldVersion < 9) {
      await _createChatTables(db);
    }
    // v10：助手消息新增「思考过程」列。
    // 注意用「存在性判断」而不是直接 ALTER —— v8 及更早升上来时 chat_messages
    // 是上面 _createChatTables 刚建出来的，建表语句里已经带上了这一列，
    // 直接 ALTER 会报 duplicate column name。
    if (oldVersion < 10) {
      await _addColumnIfMissing(
        db,
        DatabaseConstants.tableChatMessages,
        DatabaseConstants.colReasoning,
        "TEXT DEFAULT ''",
      );
    }
    // v11：日记新增「写这篇时的天气 / 地点」快照。
    // 同样走存在性判断 —— 全新安装时这两列已由 _onCreate 建好。
    if (oldVersion < 11) {
      await _addColumnIfMissing(
        db,
        DatabaseConstants.tableDiaryEntries,
        DatabaseConstants.colWeather,
        "TEXT DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        DatabaseConstants.tableDiaryEntries,
        DatabaseConstants.colLocation,
        "TEXT DEFAULT ''",
      );
    }
  }

  /// 加列前先查 PRAGMA table_info，列已存在就跳过（迁移可重复执行）
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    if (await _columnExists(db, table, column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<bool> _columnExists(
    Database db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in rows) {
      if (row['name'] == column) return true;
    }
    return false;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
