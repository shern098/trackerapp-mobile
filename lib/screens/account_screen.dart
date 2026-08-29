import 'package:flutter/material.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      // TODO: Hook this up to Practical 11's Supabase auth if you want
      // real sign-in/sign-up instead of a static placeholder.
      body: const Center(child: Text('Account details go here.')),
    );
  }
}
