// import 'package:flutter/material.dart';
// import '../screens/bus_screen.dart';
// import '../screens/train_screen.dart';
//
// class AppDrawer extends StatelessWidget {
//   const AppDrawer({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Drawer(
//       child: SafeArea(
//         child: Column(
//           children: [
//
//             // Header
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(20),
//               child: const Text(
//                 'Transport Tracker',
//                 style: TextStyle(
//                   fontSize: 22,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//
//             const Divider(),
//
//             // Main options
//             ListTile(
//               leading: const Icon(Icons.directions_bus),
//               title: const Text('Bus'),
//               onTap: () {
//                 Navigator.pop(context);
//
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const BusScreen(),
//                   ),
//                 );
//               },
//             ),
//
//             ListTile(
//               leading: const Icon(Icons.train),
//               title: const Text('Train'),
//               onTap: () {
//                 Navigator.pop(context);
//
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const TrainScreen(),
//                   ),
//                 );
//               },
//             ),
//
//             ListTile(
//               leading: const Icon(
//                 Icons.route,
//               ),
//               title: const Text('Plan Journey'),
//               onTap: () {
//                 Navigator.pop(context);
//               },
//             ),
//
//             // Push Account and Settings to bottom
//             const Spacer(),
//
//             const Divider(),
//
//             ListTile(
//               leading: const Icon(
//                 Icons.account_circle,
//               ),
//               title: const Text('Account'),
//               onTap: () {
//                 Navigator.pop(context);
//               },
//             ),
//
//             ListTile(
//               leading: const Icon(
//                 Icons.settings,
//               ),
//               title: const Text('Settings'),
//               onTap: () {
//                 Navigator.pop(context);
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:trackerapp/screens/account_screen.dart';
import '../screens/bus_screen.dart';
import '../screens/train_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Transport Tracker',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const Divider(),

            // Bus
            ListTile(
              leading: const Icon(
                Icons.directions_bus,
              ),
              title: const Text('Bus'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const BusScreen(),
                  ),
                );
              },
            ),

            // Train
            ListTile(
              leading: const Icon(
                Icons.train,
              ),
              title: const Text('Train'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const TrainScreen(),
                  ),
                );
              },
            ),

            // Plan Journey
            ListTile(
              leading: const Icon(
                Icons.route,
              ),
              title: const Text('Plan Journey'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Spacer(),

            const Divider(),

            // Account
            ListTile(
              leading: const Icon(
                Icons.account_circle,
              ),
              title: const Text('Account'),
              onTap: () async {
                Navigator.pop(context);

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                    const AccountScreen(),
                  ),
                );
              },
            ),

            // Settings
            ListTile(
              leading: const Icon(
                Icons.settings,
              ),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}