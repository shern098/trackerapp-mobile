import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart' show currentUserNotifier, themeModeNotifier;
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../models/user_model.dart';

/// Shows the signed-in user's profile picture (tap to change — same
/// image_picker + "copy into app documents folder" pattern as Practical
/// 8's Data File example, just with a per-user filename instead of one
/// single app-wide profile.png so multiple accounts don't overwrite each
/// other's picture) plus their username and a logout button.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker(); // same instance pattern as Practical 8
  File? _image;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  // Same shape as Practical 8's loadProfileImage() — checks whether a
  // saved picture file already exists for this user and shows it if so.
  void _loadProfileImage() {
    final user = currentUserNotifier.value;
    if (user?.profilePicturePath == null) return;
    final file = File(user!.profilePicturePath!);
    if (file.existsSync()) {
      setState(() => _image = file);
    }
  }

  // Same shape as Practical 8's getImageFromGallery().
  Future<void> _pickAndSaveImage() async {
    final user = currentUserNotifier.value;
    if (user == null) return;

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    // Same shape as Practical 8's savePicture() — copies the picked file
    // into the app's own documents folder. The filename includes the
    // user's id so each account's picture is stored separately.
    final appDocDir = await getApplicationDocumentsDirectory();
    final newImagePath = '${appDocDir.path}/profile_${user.id}.png';
    final savedImage = await File(pickedFile.path).copy(newImagePath);

    await _authService.updateProfilePicture(user, newImagePath);
    currentUserNotifier.value = user.copyWith(profilePicturePath: newImagePath);

    setState(() => _image = savedImage);
  }

  void _logout() async {
    await _authService.logout();
    currentUserNotifier.value = null;
    // Restore whatever the guest theme preference actually was, rather
    // than hardcoding back to Light — a guest who prefers Dark shouldn't
    // get bounced to Light just because they logged out of an account
    // that happened to be set to Light.
    themeModeNotifier.value = await ThemeService().loadThemeMode();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = currentUserNotifier.value;

    if (user == null) {
      // Shouldn't normally happen (the drawer only routes here when
      // logged in), but guards against a stale navigation stack.
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Center(child: Text('You are not signed in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndSaveImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _image != null ? FileImage(_image!) : null,
                child: _image == null ? const Icon(Icons.person, size: 50) : null,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Tap to change profile picture', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Text(user.username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _logout,
                child: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
