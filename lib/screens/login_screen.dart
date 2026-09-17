import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _accountNameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _debounce;
  bool _isCheckingAccountName = false;
  bool? _isAccountNameAvailable;

  final _supabase = Supabase.instance.client;

  Future<bool> _checkAccountNameAvailable(String name) async {
    final result = await _supabase.rpc(
      'is_account_name_available',
      params: {'name': name},
    );
    return result as bool;
  }

  void _onAccountNameChanged(String value) {
    _debounce?.cancel();
    setState(() => _isAccountNameAvailable = null);

    final trimmed = value.trim();
    if (trimmed.isEmpty || !_isValidAccountNameFormat(trimmed)) return;

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCheckingAccountName = true);
      final available = await _checkAccountNameAvailable(trimmed);
      if (mounted) {
        setState(() {
          _isAccountNameAvailable = available;
          _isCheckingAccountName = false;
        });
      }
    });
  }

  bool _isValidAccountNameFormat(String value) {
    return value.length >= 3 &&
        value.length <= 20 &&
        RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value);
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        final accountName = _accountNameController.text.trim();

        if (!_isValidAccountNameFormat(accountName)) {
          setState(() => _errorMessage =
          'Account name must be 3–20 characters, letters/numbers/underscores only');
          return;
        }

        final available = await _checkAccountNameAvailable(accountName);
        if (!available) {
          setState(() => _errorMessage = 'Account name is already taken');
          return;
        }

        await _supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'full_name': _displayNameController.text.trim(),
            'account_name': accountName,
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please check your email to verify your account.'),
              duration: Duration(seconds: 5),
            ),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- Forgot password flow ----
  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());

    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        // Must match a URL registered in Supabase Dashboard ->
        // Authentication -> URL Configuration -> Redirect URLs,
        // and a scheme your app listens for natively.
        redirectTo: 'io.supabase.flutterquickstart://reset-callback/',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your email for a reset link')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Widget? _buildAccountNameSuffix() {
    if (_isCheckingAccountName) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_isAccountNameAvailable == null) return null;
    return Icon(
      _isAccountNameAvailable! ? Icons.check_circle : Icons.cancel,
      color: _isAccountNameAvailable! ? Colors.green : Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign Up' : 'Log In')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isSignUp) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _accountNameController,
                  onChanged: _onAccountNameChanged,
                  decoration: InputDecoration(
                    labelText: 'Account Name (permanent)',
                    helperText: 'Letters, numbers, underscores. Cannot be changed later.',
                    border: const OutlineInputBorder(),
                    suffixIcon: _buildAccountNameSuffix(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            // "Forgot Password?" only shown in log-in mode.
            if (!_isSignUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Forgot Password?'),
                ),
              ),

            const SizedBox(height: 12),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _submit,
              child: Text(_isSignUp ? 'Sign Up' : 'Log In'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Log In'
                    : "Don't have an account? Sign Up",
              ),
            ),
          ],
        ),
      ),
    );
  }
}