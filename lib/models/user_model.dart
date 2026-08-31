/// Represents one row from the "Users" SQLite table — a registered
/// account. passwordHash is a SHA-256 hash (never the plain password —
/// see auth_service.dart), profilePicturePath points to a locally-copied
/// image file (same idea as Practical 8's Data File practical, just
/// scoped per-user instead of one single app-wide profile.png), and
/// themeMode is this user's saved Light/Dark preference.
class UserModel {
  final int id;
  final String username;
  final String passwordHash;
  final String? profilePicturePath;
  final String themeMode; // 'light' or 'dark'

  UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.profilePicturePath,
    required this.themeMode,
  });

  factory UserModel.fromJson(Map<String, dynamic> data) => UserModel(
        id: data['id'],
        username: data['username'],
        passwordHash: data['passwordHash'],
        profilePicturePath: data['profilePicturePath'],
        themeMode: data['themeMode'] ?? 'light',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'profilePicturePath': profilePicturePath,
        'themeMode': themeMode,
      };

  // Fields are immutable (`final`) — used to build an updated copy after
  // changing the profile picture or theme, without touching username/password.
  UserModel copyWith({String? profilePicturePath, String? themeMode}) => UserModel(
        id: id,
        username: username,
        passwordHash: passwordHash,
        profilePicturePath: profilePicturePath ?? this.profilePicturePath,
        themeMode: themeMode ?? this.themeMode,
      );
}
