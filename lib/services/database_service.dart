import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/bus_model.dart';
import '../models/train_model.dart';
import '../models/notification_alert_model.dart';
import '../models/user_model.dart';

/// All local SQLite storage for the app. Structured the same way as
/// Practical 9's DatabaseService: a singleton, with matching
/// get/insert/update/delete methods for each table.
///
/// Buses, Trains, and NotificationAlerts all now carry a `userId` column
/// so each account's saved data is kept separate — every read/write for
/// those three tables takes a userId parameter and filters/tags rows with
/// it accordingly.
class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    final getDirectory = await getApplicationDocumentsDirectory();
    String path = '${getDirectory.path}/transport_tracker.db';
    log(path);
    return await openDatabase(
      path,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      version: 3,
    );
  }

  // Runs once, only for a brand-new install — creates all tables already
  // at the latest schema (including userId columns and the Users table).
  void _onCreate(Database db, int version) async {
    await _createUsersTable(db);

    await db.execute(
        'CREATE TABLE Buses('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'userId INTEGER, '
        'busNumber TEXT, '
        'iconVisible INTEGER DEFAULT 1, '
        'routeVisible INTEGER DEFAULT 1)');

    await db.execute(
        'CREATE TABLE Trains('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'userId INTEGER, '
        'lineName TEXT, '
        'visible INTEGER DEFAULT 1)');

    await db.execute(
        'CREATE TABLE NotificationAlerts('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'userId INTEGER, '
        'name TEXT, '
        'location TEXT, '
        'latitude REAL DEFAULT 0, '
        'longitude REAL DEFAULT 0, '
        'type TEXT, '
        'routeRef TEXT, '
        'startTime TEXT, '
        'endTime TEXT, '
        'sound TEXT, '
        'vibrate TEXT)');

    log('TABLES CREATED');
  }

  // Shared by _onCreate (fresh installs) and _onUpgrade (v1/v2 -> v3
  // migration) so the Users table schema only needs to be written once.
  Future<void> _createUsersTable(Database db) async {
    await db.execute(
        'CREATE TABLE Users('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'username TEXT UNIQUE, '
        'passwordHash TEXT, '
        'profilePicturePath TEXT, '
        'themeMode TEXT DEFAULT \'light\')');
  }

  // Handles users upgrading from older schema versions, oldest-first, so
  // someone jumping straight from v1 to v3 gets both migrations applied.
  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE NotificationAlerts ADD COLUMN latitude REAL DEFAULT 0');
      await db.execute('ALTER TABLE NotificationAlerts ADD COLUMN longitude REAL DEFAULT 0');
      log('MIGRATED DB TO VERSION 2 (added latitude/longitude)');
    }
    if (oldVersion < 3) {
      await _createUsersTable(db);
      await db.execute('ALTER TABLE Buses ADD COLUMN userId INTEGER');
      await db.execute('ALTER TABLE Trains ADD COLUMN userId INTEGER');
      await db.execute('ALTER TABLE NotificationAlerts ADD COLUMN userId INTEGER');
      log('MIGRATED DB TO VERSION 3 (added Users table + userId columns)');
    }
  }

  // ---------- User CRUD ----------

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final data = await db.query('Users', where: 'username = ?', whereArgs: [username]);
    if (data.isEmpty) return null;
    return UserModel.fromJson(data.first);
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final data = await db.query('Users', where: 'id = ?', whereArgs: [id]);
    if (data.isEmpty) return null;
    return UserModel.fromJson(data.first);
  }

  // Returns the new user's id (SQLite auto-assigns it via rawInsert's
  // return value), used so AuthService can build a full UserModel right
  // after registering without a second query.
  Future<int> insertUser(String username, String passwordHash) async {
    final db = await database;
    final id = await db.rawInsert(
        'INSERT INTO Users(username, passwordHash, profilePicturePath, themeMode) VALUES(?,?,?,?)',
        [username, passwordHash, null, 'light']);
    log('inserted user $id');
    return id;
  }

  Future<void> updateUser(UserModel user) async {
    final db = await database;
    await db.update('Users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
    log('updated user ${user.id}');
  }

  // ---------- Bus CRUD (all scoped to userId) ----------

  Future<List<BusModel>> getBuses(int userId) async {
    final db = await database;
    var data = await db.query('Buses', where: 'userId = ?', whereArgs: [userId]);
    return List.generate(data.length, (index) => BusModel.fromJson(data[index]));
  }

  Future<void> insertBus(int userId, String busNumber) async {
    final db = await database;
    var data = await db.rawInsert(
        'INSERT INTO Buses(userId, busNumber, iconVisible, routeVisible) VALUES(?,?,?,?)',
        [userId, busNumber, 1, 1]);
    log('inserted bus $data');
  }

  Future<void> updateBus(BusModel bus) async {
    final db = await database;
    var data =
        await db.update('Buses', bus.toMap(), where: 'id=?', whereArgs: [bus.id]);
    log('updated bus $data');
  }

  Future<void> deleteBus(int id) async {
    final db = await database;
    var data = await db.delete('Buses', where: 'id = ?', whereArgs: [id]);
    log('deleted bus $data');
  }

  // ---------- Train CRUD (all scoped to userId) ----------

  Future<List<TrainModel>> getTrains(int userId) async {
    final db = await database;
    var data = await db.query('Trains', where: 'userId = ?', whereArgs: [userId]);
    return List.generate(data.length, (index) => TrainModel.fromJson(data[index]));
  }

  Future<void> insertTrain(int userId, String lineName) async {
    final db = await database;
    var data = await db.rawInsert(
        'INSERT INTO Trains(userId, lineName, visible) VALUES(?,?,?)',
        [userId, lineName, 1]);
    log('inserted train $data');
  }

  Future<void> updateTrain(TrainModel train) async {
    final db = await database;
    var data = await db
        .update('Trains', train.toMap(), where: 'id=?', whereArgs: [train.id]);
    log('updated train $data');
  }

  Future<void> deleteTrain(int id) async {
    final db = await database;
    var data = await db.delete('Trains', where: 'id = ?', whereArgs: [id]);
    log('deleted train $data');
  }

  // ---------- Notification Alert CRUD (scoped to userId AND type) ----------

  Future<List<NotificationAlertModel>> getNotifications(int userId, String type) async {
    final db = await database;
    var data = await db.query('NotificationAlerts',
        where: 'userId = ? AND type = ?', whereArgs: [userId, type]);
    return List.generate(
        data.length, (index) => NotificationAlertModel.fromJson(data[index]));
  }

  Future<void> insertNotification(int userId, NotificationAlertModel alert) async {
    final db = await database;
    var data = await db.rawInsert(
        'INSERT INTO NotificationAlerts'
        '(userId, name, location, latitude, longitude, type, routeRef, startTime, endTime, sound, vibrate) '
        'VALUES(?,?,?,?,?,?,?,?,?,?,?)',
        [
          userId,
          alert.name,
          alert.location,
          alert.latitude,
          alert.longitude,
          alert.type,
          alert.routeRef,
          alert.startTime,
          alert.endTime,
          alert.sound,
          alert.vibrate,
        ]);
    log('inserted notification $data');
  }

  Future<void> deleteNotification(int id) async {
    final db = await database;
    var data =
        await db.delete('NotificationAlerts', where: 'id = ?', whereArgs: [id]);
    log('deleted notification $data');
  }
}
