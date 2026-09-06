import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart' show currentUserNotifier, themeModeNotifier;
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../models/user_model.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker();
  File? _image;
  bool _isSavingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  void _loadProfileImage() {
    final user = currentUserNotifier.value;
    if (user?.profilePicturePath == null) return;
    final file = File(user!.profilePicturePath!);
    if (file.existsSync()) {
      setState(() => _image = file);
    }
  }

  Future<void> _pickAndSaveImage() async {
    final user = currentUserNotifier.value;
    if (user == null || _isSavingImage) return;

    setState(() => _isSavingImage = true);

    try{
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final appDocDir = await getApplicationDocumentsDirectory();
      final newImagePath = '${appDocDir.path}/profile_${user.id}.png';
      final savedImage = await File(pickedFile.path).copy(newImagePath);

      await _authService.updateProfilePicture(user, newImagePath);
      currentUserNotifier.value = user.copyWith(profilePicturePath: newImagePath);

      if(!mounted)return;
      setState(() => _image = savedImage);
    }catch(e){
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile picture: $e')),
      );
    }finally{
      if (mounted) setState(()=>_isSavingImage = false);
    }
  }

  void _logout() async {
    await _authService.logout();
    currentUserNotifier.value = null;
    final guestTheme = await ThemeService().loadThemeMode();
    themeModeNotifier.value = guestTheme;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final UserModel? user = currentUserNotifier.value;

    if (user == null) {
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
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _image != null ? FileImage(_image!) : null,
                    child: _image == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  if (_isSavingImage)
                    const Positioned.fill(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.black45,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    )
                  else
                    const CircleAvatar(
                      radius: 14,
                      child: Icon(Icons.edit, size: 14),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text('Tap to change profile picture',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Text(user.username,
                style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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