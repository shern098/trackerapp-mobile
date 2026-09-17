import 'package:flutter/material.dart';

import '../models/route.dart';
import '../services/gtfs_supabase_service.dart';
import '../services/tracked_routes_service.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  final GtfsSupabaseService _gtfsService = GtfsSupabaseService();
  final TrackedRoutesService _trackedRoutesService = TrackedRoutesService();

  final List<GtfsRoute> _trackingRoutes = [];
  final Map<String, bool> _routeEnabled = {};
  bool _loadingRoutes = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final trackedMap = await _trackedRoutesService.getTrackedRoutes('train');
      final trackingRoutes =
      await _gtfsService.getTrainRoutesByKeys(trackedMap.keys.toList());

      final enabled = <String, bool>{};
      for (final route in trackingRoutes) {
        enabled[route.uniqueKey] = trackedMap[route.uniqueKey] ?? false;
      }

      if (!mounted) return;
      setState(() {
        _trackingRoutes.clear();
        _trackingRoutes.addAll(trackingRoutes);
        _routeEnabled.clear();
        _routeEnabled.addAll(enabled);
        _loadingRoutes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoutes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load train routes: $e')),
      );
    }
  }

  Future<void> _removeRoute(GtfsRoute route) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Train Route?'),
          content: Text(
            'Are you sure you want to remove '
                'route ${route.shortName} from your tracked trains?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _trackingRoutes.removeWhere(
            (existing) => existing.uniqueKey == route.uniqueKey,
      );
      _routeEnabled.remove(route.uniqueKey);
    });

    try {
      await _trackedRoutesService.removeRoute(
        routeKey: route.uniqueKey,
        routeType: 'train',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove route: $e')),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Route ${route.shortName} removed.')),
    );
  }

  void _showAddRouteDialog() {
    List<GtfsRoute> availableRoutes = [];
    GtfsRoute? selectedRoute;
    bool loading = true;
    String? loadError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadRoutes() async {
              setDialogState(() {
                loading = true;
                loadError = null;
              });

              try {
                final routes = await _gtfsService.getTrainRoutes();
                final available = routes
                    .where((route) => !_trackingRoutes.any(
                        (existing) => existing.uniqueKey == route.uniqueKey))
                    .toList();

                setDialogState(() {
                  availableRoutes = available;
                  selectedRoute =
                  available.isNotEmpty ? available.first : null;
                  loading = false;
                });
              } catch (e) {
                setDialogState(() {
                  loadError = 'Failed to load routes: $e';
                  loading = false;
                });
              }
            }

            if (loading && availableRoutes.isEmpty && loadError == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadRoutes();
              });
            }

            return AlertDialog(
              title: const Text('Add Train Route'),
              content: loading
                  ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              )
                  : loadError != null
                  ? Text(loadError!,
                  style: const TextStyle(color: Colors.red))
                  : availableRoutes.isEmpty
                  ? const Text(
                  'All train routes have already been added.')
                  : DropdownButtonFormField<GtfsRoute>(
                value: selectedRoute,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Train Route',
                  border: OutlineInputBorder(),
                ),
                items: availableRoutes.map((route) {
                  return DropdownMenuItem<GtfsRoute>(
                    value: route,
                    child: Text(
                      '${route.shortName} - ${route.longName}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (route) {
                  setDialogState(() => selectedRoute = route);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedRoute == null
                      ? null
                      : () async {
                    final route = selectedRoute!;
                    setState(() {
                      _trackingRoutes.add(route);
                      _routeEnabled[route.uniqueKey] = true;
                    });

                    try {
                      await _trackedRoutesService.upsertRoute(
                        routeKey: route.uniqueKey,
                        routeType: 'train',
                        isEnabled: true,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                              Text('Failed to save route: $e')),
                        );
                      }
                    }

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
              Tab(icon: Icon(Icons.train), text: 'Track Train'),
              Tab(icon: Icon(Icons.notifications), text: 'Notification'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildTrackTrainTab(), _buildNotificationTab()],
        ),
      ),
    );
  }

  Widget _buildTrackTrainTab() {
    if (_loadingRoutes) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        _trackingRoutes.isEmpty
            ? const Center(
          child: Text('No train routes being tracked.',
              style: TextStyle(fontSize: 16)),
        )
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          itemCount: _trackingRoutes.length,
          itemBuilder: (context, index) {
            final route = _trackingRoutes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.train)),
                title: Text(route.shortName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(route.longName),
                trailing: Switch(
                  value: _routeEnabled[route.uniqueKey] ?? false,
                  onChanged: (value) async {
                    setState(() => _routeEnabled[route.uniqueKey] = value);
                    try {
                      await _trackedRoutesService.upsertRoute(
                        routeKey: route.uniqueKey,
                        routeType: 'train',
                        isEnabled: value,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to update route: $e')),
                      );
                    }
                  },
                ),
                onLongPress: () => _removeRoute(route),
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
      child: Text('No train notifications.', style: TextStyle(fontSize: 16)),
    );
  }
}