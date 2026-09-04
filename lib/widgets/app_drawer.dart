import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1C1C1C),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracker App',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Divider(color: Colors.white54),
                ],
              ),
            ),

            _sectionHeader(Icons.directions_bus, 'Bus Configuration'),
            _drawerItem(context, 'Bus List', '/bus_list'),
            const SizedBox(height: 20),

            _sectionHeader(Icons.train, 'Train Configuration'),
            _drawerItem(context, 'Train List', '/train_list'),

            const Spacer(),

            _drawerItem(context, 'Settings', '/settings', icon: Icons.settings_outlined),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, String route,
      {IconData? icon}) {
    return ListTile(
      leading: icon != null ? Icon(icon, color: Colors.white) : null,
      contentPadding: EdgeInsets.only(left: icon != null ? 20 : 52, right: 20),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 16)),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }
}
