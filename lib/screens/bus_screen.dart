import 'package:flutter/material.dart';

import '../models/route.dart';
import '../services/gtfs_supabase_service.dart';
import '../services/tracked_routes_service.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final GtfsSupabaseService _gtfsService = GtfsSupabaseService();
  final TrackedRoutesService _trackedRoutesService = TrackedRoutesService();

  final List<GtfsRoute> _trackingRoutes = [];
  final Map<String, bool> _routeEnabled = {};
  List<String> _feedCategories = [];
  bool _loadingRoutes = true;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    try {
      final feedCategories = await _gtfsService.getFeedCategories();
      final trackedMap = await _trackedRoutesService.getTrackedRoutes('bus');

      final trackingRoutes =
      await _gtfsService.getRoutesByKeys(trackedMap.keys.toList());

      final enabled = <String, bool>{};
      for (final route in trackingRoutes) {
        enabled[route.uniqueKey] = trackedMap[route.uniqueKey] ?? false;
      }

      if (!mounted) return;
      setState(() {
        _feedCategories = feedCategories;
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
        SnackBar(content: Text('Failed to load bus routes: $e')),
      );
    }
  }

  Future<void> _removeRoute(GtfsRoute route) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Bus Route?'),
          content: Text(
            'Are you sure you want to remove '
                'route ${route.shortName} from your tracked buses?',
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
        routeType: 'bus',
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
    if (_feedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bus feeds available.')),
      );
      return;
    }

    String selectedFeedCategory = _feedCategories.first;
    List<GtfsRoute> feedRoutes = [];
    GtfsRoute? selectedRoute;
    bool loadingFeedRoutes = true;
    String? loadError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadFeedRoutes(String feedCategory) async {
              setDialogState(() {
                loadingFeedRoutes = true;
                loadError = null;
              });

              try {
                final routes = await _gtfsService.getRoutes(
                  feedCategory: feedCategory,
                );
                final available = routes
                    .where((route) => !_trackingRoutes.any(
                        (existing) => existing.uniqueKey == route.uniqueKey))
                    .toList();

                setDialogState(() {
                  feedRoutes = available;
                  selectedRoute =
                  available.isNotEmpty ? available.first : null;
                  loadingFeedRoutes = false;
                });
              } catch (e) {
                setDialogState(() {
                  loadError = 'Failed to load routes: $e';
                  loadingFeedRoutes = false;
                });
              }
            }

            if (loadingFeedRoutes && feedRoutes.isEmpty && loadError == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                loadFeedRoutes(selectedFeedCategory);
              });
            }

            return AlertDialog(
              title: const Text('Add Bus Route'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedFeedCategory,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Feed',
                      border: OutlineInputBorder(),
                    ),
                    items: _feedCategories.map((feedCategory) {
                      return DropdownMenuItem<String>(
                        value: feedCategory,
                        child:
                        Text(feedCategory, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (feedCategory) {
                      if (feedCategory == null) return;
                      selectedFeedCategory = feedCategory;
                      feedRoutes = [];
                      selectedRoute = null;
                      loadFeedRoutes(feedCategory);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (loadingFeedRoutes)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    )
                  else if (loadError != null)
                    Text(loadError!, style: const TextStyle(color: Colors.red))
                  else if (feedRoutes.isEmpty)
                      const Text(
                          'All routes in this feed have already been added.')
                    else
                      DropdownButtonFormField<GtfsRoute>(
                        value: selectedRoute,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Bus Route',
                          border: OutlineInputBorder(),
                        ),
                        items: feedRoutes.map((route) {
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
                ],
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
                        routeType: 'bus',
                        isEnabled: true,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save route: $e')),
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
          title: const Text('Bus'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.directions_bus), text: 'Track Bus'),
              Tab(icon: Icon(Icons.notifications), text: 'Notification'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildTrackBusTab(), _buildNotificationTab()],
        ),
      ),
    );
  }

  Widget _buildTrackBusTab() {
    if (_loadingRoutes) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        _trackingRoutes.isEmpty
            ? const Center(
          child: Text('No bus routes being tracked.',
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
                leading: const CircleAvatar(
                    child: Icon(Icons.directions_bus)),
                title: Text(route.shortName,
                    style:
                    const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  route.feedCategory.isNotEmpty
                      ? '${route.longName}\n${route.feedCategory}'
                      : route.longName,
                ),
                isThreeLine: route.feedCategory.isNotEmpty,
                trailing: Switch(
                  value: _routeEnabled[route.uniqueKey] ?? false,
                  onChanged: (value) async {
                    setState(() => _routeEnabled[route.uniqueKey] = value);
                    try {
                      await _trackedRoutesService.upsertRoute(
                        routeKey: route.uniqueKey,
                        routeType: 'bus',
                        isEnabled: value,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update route: $e')),
                      );
                    }
                  },
                ),
                onLongPress: () => _removeRoute(route),
                onTap: () {},
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
      child: Text('No bus notifications.', style: TextStyle(fontSize: 16)),
    );
  }
}