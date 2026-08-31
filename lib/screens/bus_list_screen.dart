import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../services/database_service.dart';
import '../main.dart' show currentUserNotifier;
import 'add_bus_screen.dart';
import 'login_screen.dart';

/// Shows the signed-in user's saved buses (from the "Buses" SQLite
/// table, filtered by userId), with per-bus visibility toggles — matches
/// the FutureBuilder + Card list pattern from Practical 9's SQLite CRUD
/// example. Guests (not signed in) see a sign-in prompt instead of an
/// empty list, since buses are per-account data now.
class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  final dbService = DatabaseService();
  Future<List<BusModel>>? _busesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // Re-fetches the bus list from SQLite, scoped to whoever is currently
  // signed in — called after any change (toggling a switch, adding a new
  // bus) so the UI stays in sync with the database.
  void _refresh() {
    final userId = currentUserNotifier.value?.id;
    setState(() {
      _busesFuture = userId != null ? dbService.getBuses(userId) : null;
    });
  }

  // Handlers for the two Switch widgets — update just the one field via
  // BusModel.copyWith(), save to the database, then refresh the list.
  void _toggleIconVisible(BusModel bus, bool value) async {
    await dbService.updateBus(bus.copyWith(iconVisible: value ? 1 : 0));
    _refresh();
  }

  void _toggleRouteVisible(BusModel bus, bool value) async {
    await dbService.updateBus(bus.copyWith(routeVisible: value ? 1 : 0));
    _refresh();
  }

  // "Add Bus" is only meaningful while signed in, since every saved bus
  // is tagged to an account. Sends guests to Login instead of Add Bus.
  void _onAddBusPressed() async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refresh(); // in case they signed in and came back
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBusScreen()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = currentUserNotifier.value == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Bus List')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: isGuest
                  ? const Center(
                      child: Text('Sign in to see and add your saved buses.',
                          textAlign: TextAlign.center),
                    )
                  : FutureBuilder<List<BusModel>>(
                      future: _busesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No buses added yet.'));
                        }
                        final buses = snapshot.data!;
                        return ListView.builder(
                          itemCount: buses.length,
                          itemBuilder: (context, index) {
                            final bus = buses[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.black26)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_bus, size: 36),
                                        const SizedBox(width: 12),
                                        Text('Bus No : ${bus.busNumber}',
                                            style: const TextStyle(
                                                fontSize: 20, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Toggle Icon Visibility'),
                                        Switch(
                                          value: bus.iconVisible == 1,
                                          onChanged: (v) => _toggleIconVisible(bus, v),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Toggle Route Visibility'),
                                        Switch(
                                          value: bus.routeVisible == 1,
                                          onChanged: (v) => _toggleRouteVisible(bus, v),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _onAddBusPressed,
                child: Text(isGuest ? 'Sign In to Add Bus' : 'Add Bus'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
