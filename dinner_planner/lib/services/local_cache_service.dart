import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalCacheService {
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  static Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'dinner_planner.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE meals_cache (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            instructions TEXT,
            image_url TEXT,
            servings INTEGER,
            source_url TEXT,
            categories TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE ingredients_cache (
            id INTEGER PRIMARY KEY,
            meal_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            quantity TEXT,
            unit TEXT,
            calories REAL,
            protein REAL,
            carbs REAL,
            fat REAL
          )
        ''');
      },
    );
  }

  // Only these columns exist in meals_cache — Supabase rows include extras like user_id, created_at
  static const _mealColumns = {
    'id', 'name', 'instructions', 'image_url', 'servings', 'source_url', 'categories',
  };

  static Future<void> upsertMeals(List<Map<String, dynamic>> rows) async {
    final db = await _database;
    final batch = db.batch();
    for (final row in rows) {
      // Strip any columns that aren't in the local schema
      final r = <String, dynamic>{};
      for (final key in _mealColumns) {
        if (row.containsKey(key)) r[key] = row[key];
      }
      if (r['categories'] is List) {
        r['categories'] = jsonEncode(r['categories']);
      }
      batch.insert('meals_cache', r, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> upsertIngredients(List<Map<String, dynamic>> rows) async {
    final db = await _database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('ingredients_cache', Map<String, dynamic>.from(row),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getMeals() async {
    final db = await _database;
    final rows = await db.query('meals_cache', orderBy: 'id DESC');
    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      // Decode categories JSON string back to list
      if (m['categories'] is String) {
        try {
          m['categories'] = jsonDecode(m['categories'] as String);
        } catch (_) {
          m['categories'] = <String>[];
        }
      }
      m['categories'] ??= <String>[];
      return m;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> getIngredients(int mealId) async {
    final db = await _database;
    return db.query('ingredients_cache',
        where: 'meal_id = ?', whereArgs: [mealId]);
  }

  static Future<void> deleteMeal(int id) async {
    final db = await _database;
    await db.delete('meals_cache', where: 'id = ?', whereArgs: [id]);
    await db.delete('ingredients_cache', where: 'meal_id = ?', whereArgs: [id]);
  }
}
