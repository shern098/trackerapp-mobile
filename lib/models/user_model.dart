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

  UserModel copyWith({String? profilePicturePath, String? themeMode}) => UserModel(
        id: id,
        username: username,
        passwordHash: passwordHash,
        profilePicturePath: profilePicturePath ?? this.profilePicturePath,
        themeMode: themeMode ?? this.themeMode,
      );
}
