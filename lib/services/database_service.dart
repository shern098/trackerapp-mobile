import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/bus_model.dart';
import '../models/train_model.dart';
import '../models/notification_alert_model.dart';
import '../models/user_model.dart';

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
    String path = '${getDirectory.path}/trackerapp.db';
    log(path);
    return await openDatabase(
      path,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      version: 1,
    );
  }

  void _onCreate(Database db, int version) async {
    await db.execute(
        'CREATE TABLE Users('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'username TEXT UNIQUE, '
            'passwordHash TEXT, '
            'profilePicturePath TEXT, '
            'themeMode TEXT DEFAULT \'light\')');

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
            'routeRef TEXT, '
            'sound TEXT, '
            'vibrate TEXT)');

    log('TABLES CREATED');
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    //to be use if updating stuff to db
  }

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

  Future<List<BusModel>> getBuses(int userId) async {
    final db = await database;
    var data = await db.query('Buses', where: 'userId = ?', whereArgs: [userId]);
    return List.generate(data.length, (index) => BusModel.fromJson(data[index]));
  }

  Future<void> insertBus(BuildContext context, int userId, String busNumber) async {
    final db = await database;
    final existing = await db.rawQuery(
      'SELECT 1 FROM Buses WHERE userId = ? AND busNumber = ?',
      [userId, busNumber],
    );
    if (existing.isNotEmpty) {
      log('Bus number already exists!');
      if(context.mounted){
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bus number already exists!'),
              duration: Duration(seconds: 2),
            ),
        );
      }
      return;
    }else{
      var data = await db.rawInsert(
          'INSERT INTO Buses(userId, busNumber, iconVisible, routeVisible) VALUES(?,?,?,?)',
          [userId, busNumber, 1, 1]);
      log('inserted bus id: $data');
    }
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

  Future<List<NotificationAlertModel>> getNotifications(int userId) async {
    final db = await database;
    var data = await db.query('NotificationAlerts', where: 'userId = ?', whereArgs: [userId]);
    return List.generate(
        data.length, (index) => NotificationAlertModel.fromJson(data[index]));
  }

  Future<void> insertNotification(int userId, NotificationAlertModel alert) async {
    final db = await database;
    var data = await db.rawInsert(
        'INSERT INTO NotificationAlerts(userId, routeRef, sound, vibrate) '
            'VALUES(?,?,?,?)',
        [
          userId,
          alert.routeRef,
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
