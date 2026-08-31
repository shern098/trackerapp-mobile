import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'database_service.dart';

/// Handles account registration, login, logout, and "who's currently
/// signed in" — the last part persisted via SharedPreferences (same
/// get/set pattern as Practical 7) so the session survives an app
/// restart, the same way a real app wouldn't make you log in every time
/// you reopen it.
///
/// Passwords are never stored as plain text — only a SHA-256 hash of the
/// password is saved to the Users table. This is a basic, dependency-free
/// approach suitable for a course project; a production app would add a
/// per-user random "salt" on top of this for stronger protection.
class AuthService {
  static const _currentUserIdKey = 'currentUserId';

  final _dbService = DatabaseService();

  // One-way transform: same input always produces the same hash, but the
  // hash can't be reversed back into the original password.
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Creates a new account. Returns the new UserModel, or null if the
  /// username is already taken.
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
    await _setCurrentUserId(id); // auto-login right after registering
    return user;
  }

  /// Checks username + password against the Users table. Returns the
  /// UserModel on success, or null if the username doesn't exist or the
  /// password doesn't match.
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

  /// Called on app startup to restore the previous session, if any —
  /// returns null if nobody was logged in last time the app closed.
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
