import '/kernel/models/face.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), 'faces_v3.db');
    _db = await openDatabase(
      path,
      version: 4, // Incrémenté pour la table product_popularity
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE faces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            matricule TEXT,
            name TEXT,
            embedding TEXT,
            image_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE current_accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            identifier TEXT UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE product_popularity (
            product_id INTEGER PRIMARY KEY,
            sale_count INTEGER DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_matricule ON faces (matricule)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE faces ADD COLUMN name TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE current_accounts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              identifier TEXT UNIQUE
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE product_popularity (
              product_id INTEGER PRIMARY KEY,
              sale_count INTEGER DEFAULT 0
            )
          ''');
        }
      },
    );
  }

  // --- Gestion des Faces ---
  Future<void> insertFace(FacePicture face) async {
    await init();
    await _db!.insert('faces', face.toMap());
  }

  Future<List<FacePicture>> getAllFaces() async {
    await init();
    final List<Map<String, dynamic>> maps = await _db!.query('faces');
    return maps.map(FacePicture.fromMap).toList();
  }

  Future<void> deleteFace(String matricule) async {
    await init();
    await _db!.delete('faces', where: 'matricule = ?', whereArgs: [matricule]);
  }

  // --- Gestion des Comptes Récents ---
  Future<void> insertAccount(String identifier) async {
    await init();
    await _db!.insert(
      'current_accounts',
      {'identifier': identifier},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getAccounts() async {
    await init();
    final List<Map<String, dynamic>> maps = await _db!.query('current_accounts', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => maps[i]['identifier'] as String);
  }

  Future<void> deleteAccount(String identifier) async {
    await init();
    await _db!.delete(
      'current_accounts',
      where: 'identifier = ?',
      whereArgs: [identifier],
    );
  }

  // --- Gestion de la popularité des produits ---
  Future<void> incrementProductPopularity(int productId, int quantity) async {
    await init();
    await _db!.execute('''
      INSERT INTO product_popularity (product_id, sale_count)
      VALUES (?, ?)
      ON CONFLICT(product_id) DO UPDATE SET sale_count = sale_count + ?
    ''', [productId, quantity, quantity]);
  }

  Future<List<int>> getPopularProductIds({int limit = 10}) async {
    await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      'product_popularity',
      columns: ['product_id'],
      orderBy: 'sale_count DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => maps[i]['product_id'] as int);
  }

  Future<void> deleteAll() async {
    await init();
    await _db!.delete('faces');
    await _db!.delete('current_accounts');
    await _db!.delete('product_popularity');
  }
}
