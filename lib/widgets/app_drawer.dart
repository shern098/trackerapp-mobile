import 'package:flutter/material.dart';
import '../main.dart' show currentUserNotifier, showBusesNotifier;
import '../models/user_model.dart';

/// The slide-out navigation drawer shown on the Map screen. Matches the
/// original wireframe (Bus/Train Configuration sections + Settings) with
/// two additions: a "Show All Buses" switch that controls whether live
/// bus markers render on the map at all, and an Account entry that opens
/// AccountScreen if signed in, or LoginScreen otherwise.
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
            // App title header
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transport Tracker',
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

            // Master toggle for all live bus markers on the map. Wrapped
            // in a ValueListenableBuilder so flipping it updates the
            // switch's own visual state immediately; map_screen.dart
            // listens to the same showBusesNotifier independently to
            // decide whether to actually draw the markers.
            ValueListenableBuilder<bool>(
              valueListenable: showBusesNotifier,
              builder: (context, showBuses, _) {
                return SwitchListTile(
                  activeThumbColor: Colors.blue,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Show All Buses', style: TextStyle(color: Colors.white)),
                  value: showBuses,
                  onChanged: (value) => showBusesNotifier.value = value,
                );
              },
            ),
            const SizedBox(height: 8),

            // Bus section — links to the saved-buses list and the
            // bus-specific notification alerts list
            _sectionHeader(Icons.directions_bus, 'Bus Configuration'),
            _drawerItem(context, 'Bus List', '/bus_list'),
            _drawerItem(context, 'Bus Notification Setting', '/bus_notifications'),
            const SizedBox(height: 20),

            // Train section — same shape as the bus section above
            _sectionHeader(Icons.train, 'Train Configuration'),
            _drawerItem(context, 'Train List', '/train_list'),
            _drawerItem(context, 'Train Notification Setting', '/train_notifications'),

            // Pushes Account/Settings to the bottom of the drawer
            // regardless of how much content is above it
            const Spacer(),

            // Routes to Account if signed in, otherwise straight to
            // Login — avoids a dead-end "you're not signed in" screen.
            ValueListenableBuilder<UserModel?>(
              valueListenable: currentUserNotifier,
              builder: (context, user, _) {
                return _drawerItem(
                  context,
                  user == null ? 'Log In' : 'Account',
                  user == null ? '/login' : '/account',
                  icon: Icons.person_outline,
                );
              },
            ),
            _drawerItem(context, 'Settings', '/settings', icon: Icons.settings_outlined),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // A bold section title with an icon (e.g. "Bus Configuration"),
  // grouping the drawer items that follow it.
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

  // One tappable row in the drawer. Closes the drawer first, then
  // navigates to the given named route (registered in main.dart's
  // MaterialApp routes map).
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
