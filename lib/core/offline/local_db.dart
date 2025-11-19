import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'offline.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_image_analyses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT,
            image_name TEXT,
            mime_type TEXT,
            local_image_path TEXT,
            image_url TEXT,
            model TEXT,
            notes TEXT,
            raw_text TEXT,
            created_at INTEGER
          );
        ''');
      },
    );
    return _db!;
  }
}