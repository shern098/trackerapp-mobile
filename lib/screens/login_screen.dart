import 'package:flutter/material.dart';
import '../main.dart' show currentUserNotifier, themeModeNotifier;
import '../services/auth_service.dart';
import 'register_screen.dart';

/// Username + password sign-in. On success, updates currentUserNotifier
/// (which the rest of the app watches to decide what's accessible) and
/// applies that user's saved theme preference.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  String? _errorText;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_usernameController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorText = 'Please enter a username and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final user = await _authService.login(
        _usernameController.text.trim(), _passwordController.text);

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorText = 'Incorrect username or password.';
      });
      return;
    }

    // Update the app-wide "who's logged in" state and apply their saved
    // theme immediately.
    currentUserNotifier.value = user;
    themeModeNotifier.value = user.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light;

    Navigator.pop(context); // back to whichever screen sent the user here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log In')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(_errorText!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator())
                  : const Text('Log In'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
              },
              child: const Text("Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
