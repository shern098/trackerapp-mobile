import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/bus_model.dart';
import '../models/train_model.dart';
import '../models/notification_alert_model.dart';

class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();
  static Database? _database;

  // Get an instance of database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  // Initialize a database
  Future<Database> initDatabase() async {
    final getDirectory = await getApplicationDocumentsDirectory();
    String path = '${getDirectory.path}/transport_tracker.db';
    return await openDatabase(
      path,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      version: 2,
    );
  }

  // Create tables
  void _onCreate(Database db, int version) async {
    await db.execute(
        'CREATE TABLE Buses('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'busNumber TEXT, '
        'iconVisible INTEGER DEFAULT 1, '
        'routeVisible INTEGER DEFAULT 1)');

    await db.execute(
        'CREATE TABLE Trains('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'lineName TEXT, '
        'visible INTEGER DEFAULT 1)');

    await db.execute(
        'CREATE TABLE NotificationAlerts('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'name TEXT, '
        'location TEXT, '
        'type TEXT, '
        'routeRef TEXT, '
        'startTime TEXT, '
        'endTime TEXT, '
        'sound TEXT, '
        'vibrate TEXT)');

    log('TABLES CREATED');
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE NotificationAlerts ADD COLUMN latitude REAL DEFAULT 0');
      await db.execute('ALTER TABLE NotificationAlerts ADD COLUMN longitude REAL DEFAULT 0');
    }
  }

  // ---------- Bus CRUD ----------
  Future<List<BusModel>> getBuses() async {
    final db = await _databaseService.database;
    var data = await db.query('Buses');
    return List.generate(data.length, (index) => BusModel.fromJson(data[index]));
  }

  Future<void> insertBus(String busNumber) async {
    final db = await _databaseService.database;
    var data = await db.rawInsert(
        'INSERT INTO Buses(busNumber, iconVisible, routeVisible) VALUES(?,?,?)',
        [busNumber, 1, 1]);
    log('inserted bus $data');
  }

  Future<void> updateBus(BusModel bus) async {
    final db = await _databaseService.database;
    var data =
        await db.update('Buses', bus.toMap(), where: 'id=?', whereArgs: [bus.id]);
    log('updated bus $data');
  }

  Future<void> deleteBus(int id) async {
    final db = await _databaseService.database;
    var data = await db.delete('Buses', where: 'id = ?', whereArgs: [id]);
    log('deleted bus $data');
  }

  // ---------- Train CRUD ----------
  Future<List<TrainModel>> getTrains() async {
    final db = await _databaseService.database;
    var data = await db.query('Trains');
    return List.generate(data.length, (index) => TrainModel.fromJson(data[index]));
  }

  Future<void> insertTrain(String lineName) async {
    final db = await _databaseService.database;
    var data = await db.rawInsert(
        'INSERT INTO Trains(lineName, visible) VALUES(?,?)', [lineName, 1]);
    log('inserted train $data');
  }

  Future<void> updateTrain(TrainModel train) async {
    final db = await _databaseService.database;
    var data = await db
        .update('Trains', train.toMap(), where: 'id=?', whereArgs: [train.id]);
    log('updated train $data');
  }

  Future<void> deleteTrain(int id) async {
    final db = await _databaseService.database;
    var data = await db.delete('Trains', where: 'id = ?', whereArgs: [id]);
    log('deleted train $data');
  }

  // ---------- Notification Alert CRUD ----------
  Future<List<NotificationAlertModel>> getNotifications(String type) async {
    final db = await _databaseService.database;
    var data = await db
        .query('NotificationAlerts', where: 'type = ?', whereArgs: [type]);
    return List.generate(
        data.length, (index) => NotificationAlertModel.fromJson(data[index]));
  }

  Future<void> insertNotification(NotificationAlertModel alert) async {
    final db = await _databaseService.database;
    await db.rawInsert(
        'INSERT INTO NotificationAlerts'
            '(name, location, latitude, longitude, type, routeRef, startTime, endTime, sound, vibrate) '
            'VALUES(?,?,?,?,?,?,?,?,?,?)',
        [
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
  }

  Future<void> deleteNotification(int id) async {
    final db = await _databaseService.database;
    var data =
        await db.delete('NotificationAlerts', where: 'id = ?', whereArgs: [id]);
    log('deleted notification $data');
  }
}
