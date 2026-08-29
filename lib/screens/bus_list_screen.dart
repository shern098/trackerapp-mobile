import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../services/database_service.dart';
import 'add_bus_screen.dart';

class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  final dbService = DatabaseService();
  late Future<List<BusModel>> _busesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _busesFuture = dbService.getBuses();
    });
  }

  void _toggleIconVisible(BusModel bus, bool value) async {
    await dbService.updateBus(bus.copyWith(iconVisible: value ? 1 : 0));
    _refresh();
  }

  void _toggleRouteVisible(BusModel bus, bool value) async {
    await dbService.updateBus(bus.copyWith(routeVisible: value ? 1 : 0));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bus List')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<BusModel>>(
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
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddBusScreen()));
                  _refresh();
                },
                child: const Text('Add Bus'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
