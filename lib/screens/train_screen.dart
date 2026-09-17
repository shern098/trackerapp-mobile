import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/route.dart';
import '../services/gtfs_static_service.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  final GtfsStaticService _gtfsService =
  GtfsStaticService(directory: 'assets/gtfs');

  final List<GtfsRoute> _trackingRoutes = [];
  static const String _savedRoutesKey = 'tracked_train_routes';
  List<GtfsRoute> _availableRoutes = [];

  bool _loadingRoutes = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _saveTrackingRoutes() async {
    final prefs = await SharedPreferences.getInstance();

    final routeIds = _trackingRoutes
        .map((route) => route.id)
        .toList();

    await prefs.setStringList(
      _savedRoutesKey,
      routeIds,
    );
  }

  Future<void> _loadRoutes() async {
    try {
      final routes = await _gtfsService.getRoutes();

      final prefs = await SharedPreferences.getInstance();

      final savedRouteIds =
          prefs.getStringList(_savedRoutesKey) ?? [];

      final trainRoutes = routes
          .where((route) => route.type == 2)
          .toList();

      final savedRoutes = trainRoutes
          .where(
            (route) => savedRouteIds.contains(route.id),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        _availableRoutes = trainRoutes;
        _trackingRoutes.addAll(savedRoutes);
        _loadingRoutes = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingRoutes = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load train routes: $e',
          ),
        ),
      );
    }
  }

  void _showAddRouteDialog() {
    if (_availableRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No train routes available.'),
        ),
      );

      return;
    }

    final routes = _availableRoutes
        .where(
          (route) => !_trackingRoutes.any(
            (existing) => existing.id == route.id,
      ),
    )
        .toList();

    if (routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All train routes have already been added.'),
        ),
      );

      return;
    }

    GtfsRoute? selectedRoute = routes.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Train Route'),
              content: DropdownButtonFormField<GtfsRoute>(
                value: selectedRoute,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Train Route',
                  border: OutlineInputBorder(),
                ),
                items: routes.map(
                      (route) {
                    return DropdownMenuItem<GtfsRoute>(
                      value: route,
                      child: Text(
                        route.shortName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (route) {
                  setDialogState(() {
                    selectedRoute = route;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedRoute == null
                      ? null
                      : () async {
                    setState(() {
                      _trackingRoutes.add(selectedRoute!);
                    });

                    await _saveTrackingRoutes();

                    if (!context.mounted) return;

                    Navigator.pop(context);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Train'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.train),
                text: 'Track Train',
              ),
              Tab(
                icon: Icon(Icons.notifications),
                text: 'Notification',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTrackTrainTab(),
            _buildNotificationTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackTrainTab() {
    if (_loadingRoutes) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        _trackingRoutes.isEmpty
            ? const Center(
          child: Text(
            'No train routes being tracked.',
            style: TextStyle(fontSize: 16),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            90,
          ),
          itemCount: _trackingRoutes.length,
          itemBuilder: (context, index) {
            final route = _trackingRoutes[index];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.train),
                ),
                title: Text(
                  route.shortName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  route.longName,
                ),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // Tracking state will be added later.
                  },
                ),
                onTap: () {
                  // Later:
                  // Open MapScreen and highlight this route.
                },
              ),
            );
          },
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _showAddRouteDialog,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTab() {
    return const Center(
      child: Text(
        'No train notifications.',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}