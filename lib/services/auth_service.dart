import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';


class AuthService {
  static const _currentUserIdKey = 'currentUserId';

  final _dbService = DatabaseService();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<UserModel?> register(String username, String password) async {
    final existing = await _dbService.getUserByUsername(username);
    if (existing != null) return null; // username already taken

    final passwordHash = _hashPassword(password);
    final id = await _dbService.insertUser(username, passwordHash);
    final user = UserModel(
      id: id,
      username: username,
      passwordHash: passwordHash,
      profilePicturePath: null,
      themeMode: 'light',
    );
    await _setCurrentUserId(id);
    return user;
  }

  Future<UserModel?> login(String username, String password) async {
    final user = await _dbService.getUserByUsername(username);
    if (user == null) return null;
    if (user.passwordHash != _hashPassword(password)) return null;

    await _setCurrentUserId(user.id);
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
  }

  Future<void> _setCurrentUserId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserIdKey, id);
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_currentUserIdKey);
    if (id == null) return null;
    return _dbService.getUserById(id);
  }

  Future<void> updateThemeMode(UserModel user, String themeMode) async {
    final updated = user.copyWith(themeMode: themeMode);
    await _dbService.updateUser(updated);
  }

  Future<void> updateProfilePicture(UserModel user, String path) async {
    final updated = user.copyWith(profilePicturePath: path);
    await _dbService.updateUser(updated);
  }
}
