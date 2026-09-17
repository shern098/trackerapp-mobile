// import 'package:flutter/material.dart';
//
// import '../models/route.dart';
// import '../services/gtfs_static_service.dart';
// import '../services/route_preferences_service.dart';
//
// class BusScreen extends StatefulWidget {
//   const BusScreen({super.key});
//
//   @override
//   State<BusScreen> createState() => _BusScreenState();
// }
//
// class _BusScreenState extends State<BusScreen> {
//   final GtfsStaticService _gtfsService =
//   GtfsStaticService(
//     directory: 'assets/gtfs',
//   );
//
//   final List<GtfsRoute> _trackingRoutes = [];
//
//   final Map<String, bool> _routeEnabled = {};
//
//   List<GtfsRoute> _availableRoutes = [];
//
//   bool _loadingRoutes = true;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _loadRoutes();
//   }
//
//   // ============================================================
//   // LOAD ROUTES
//   // ============================================================
//
//   Future<void> _loadRoutes() async {
//     try {
//       final routes =
//       await _gtfsService.getRoutes();
//
//       final savedRouteIds =
//       await RoutePreferencesService
//           .getBusRoutes();
//
//       final enabledRouteIds =
//       await RoutePreferencesService
//           .getEnabledBusRoutes();
//
//       final availableRoutes = routes
//           .where(
//             (route) => route.type == 3,
//       )
//           .toList();
//
//       final trackingRoutes = availableRoutes
//           .where(
//             (route) =>
//             savedRouteIds.contains(route.id),
//       )
//           .toList();
//
//       final enabled = <String, bool>{};
//
//       for (final route in trackingRoutes) {
//         enabled[route.id] =
//             enabledRouteIds.contains(route.id);
//       }
//
//       if (!mounted) return;
//
//       setState(() {
//         _availableRoutes = availableRoutes;
//
//         _trackingRoutes.clear();
//         _trackingRoutes.addAll(
//           trackingRoutes,
//         );
//
//         _routeEnabled.clear();
//         _routeEnabled.addAll(enabled);
//
//         _loadingRoutes = false;
//       });
//     } catch (e) {
//       if (!mounted) return;
//
//       setState(() {
//         _loadingRoutes = false;
//       });
//
//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         SnackBar(
//           content: Text(
//             'Failed to load bus routes: $e',
//           ),
//         ),
//       );
//
//       print(
//         'Failed to load bus routes: $e',
//       );
//     }
//   }
//
//   // ============================================================
//   // SAVE TRACKED ROUTES
//   // ============================================================
//
//   Future<void> _saveRoutes() async {
//     await RoutePreferencesService
//         .saveBusRoutes(
//       _trackingRoutes
//           .map(
//             (route) => route.id,
//       )
//           .toList(),
//     );
//   }
//
//   // ============================================================
//   // SAVE ENABLED ROUTES
//   // ============================================================
//
//   Future<void> _saveEnabledRoutes() async {
//     final enabledRouteIds =
//     _trackingRoutes
//         .where(
//           (route) =>
//       _routeEnabled[route.id] == true,
//     )
//         .map(
//           (route) => route.id,
//     )
//         .toList();
//
//     await RoutePreferencesService
//         .saveEnabledBusRoutes(
//       enabledRouteIds,
//     );
//   }
//
//   // ============================================================
//   // REMOVE ROUTE
//   // ============================================================
//
//   Future<void> _removeRoute(
//       GtfsRoute route,
//       ) async {
//     final bool? confirmed =
//     await showDialog<bool>(
//       context: context,
//       builder: (dialogContext) {
//         return AlertDialog(
//           title: const Text(
//             'Remove Bus Route?',
//           ),
//           content: Text(
//             'Are you sure you want to remove '
//                 'route ${route.shortName} '
//                 'from your tracked buses?',
//           ),
//           actions: [
//             TextButton(
//               onPressed: () {
//                 Navigator.pop(
//                   dialogContext,
//                   false,
//                 );
//               },
//               child: const Text(
//                 'Cancel',
//               ),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(
//                   dialogContext,
//                   true,
//                 );
//               },
//               child: const Text(
//                 'Remove',
//               ),
//             ),
//           ],
//         );
//       },
//     );
//
//     if (confirmed != true) {
//       return;
//     }
//
//     setState(() {
//       _trackingRoutes.removeWhere(
//             (existing) =>
//         existing.id == route.id,
//       );
//
//       _routeEnabled.remove(
//         route.id,
//       );
//     });
//
//     await _saveRoutes();
//     await _saveEnabledRoutes();
//
//     if (!mounted) return;
//
//     ScaffoldMessenger.of(context)
//         .showSnackBar(
//       SnackBar(
//         content: Text(
//           'Route ${route.shortName} removed.',
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // ADD ROUTE
//   // ============================================================
//
//   void _showAddRouteDialog() {
//     if (_availableRoutes.isEmpty) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         const SnackBar(
//           content: Text(
//             'No bus routes available.',
//           ),
//         ),
//       );
//
//       return;
//     }
//
//     final routes = _availableRoutes
//         .where(
//           (route) => !_trackingRoutes.any(
//             (existing) =>
//         existing.id == route.id,
//       ),
//     )
//         .toList();
//
//     if (routes.isEmpty) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(
//         const SnackBar(
//           content: Text(
//             'All bus routes have already been added.',
//           ),
//         ),
//       );
//
//       return;
//     }
//
//     GtfsRoute? selectedRoute =
//         routes.first;
//
//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (
//               context,
//               setDialogState,
//               ) {
//             return AlertDialog(
//               title: const Text(
//                 'Add Bus Route',
//               ),
//               content:
//               DropdownButtonFormField<
//                   GtfsRoute>(
//                 value: selectedRoute,
//                 isExpanded: true,
//                 decoration:
//                 const InputDecoration(
//                   labelText: 'Bus Route',
//                   border:
//                   OutlineInputBorder(),
//                 ),
//                 items: routes.map(
//                       (route) {
//                     return DropdownMenuItem<
//                         GtfsRoute>(
//                       value: route,
//                       child: Text(
//                         route.shortName,
//                         overflow:
//                         TextOverflow
//                             .ellipsis,
//                       ),
//                     );
//                   },
//                 ).toList(),
//                 onChanged: (route) {
//                   setDialogState(() {
//                     selectedRoute =
//                         route;
//                   });
//                 },
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.pop(
//                       context,
//                     );
//                   },
//                   child: const Text(
//                     'Cancel',
//                   ),
//                 ),
//                 ElevatedButton(
//                   onPressed:
//                   selectedRoute == null
//                       ? null
//                       : () async {
//                     final route =
//                     selectedRoute!;
//
//                     setState(() {
//                       _trackingRoutes
//                           .add(route);
//
//                       _routeEnabled[
//                       route.id] =
//                       true;
//                     });
//
//                     await _saveRoutes();
//                     await _saveEnabledRoutes();
//
//                     if (!context
//                         .mounted) {
//                       return;
//                     }
//
//                     Navigator.pop(
//                       context,
//                     );
//                   },
//                   child: const Text(
//                     'Confirm',
//                   ),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
//
//   // ============================================================
//   // BUILD
//   // ============================================================
//
//   @override
//   Widget build(
//       BuildContext context,
//       ) {
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         appBar: AppBar(
//           title: const Text('Bus'),
//           bottom: const TabBar(
//             tabs: [
//               Tab(
//                 icon: Icon(
//                   Icons.directions_bus,
//                 ),
//                 text: 'Track Bus',
//               ),
//               Tab(
//                 icon: Icon(
//                   Icons.notifications,
//                 ),
//                 text: 'Notification',
//               ),
//             ],
//           ),
//         ),
//         body: TabBarView(
//           children: [
//             _buildTrackBusTab(),
//             _buildNotificationTab(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ============================================================
//   // TRACK BUS TAB
//   // ============================================================
//
//   Widget _buildTrackBusTab() {
//     if (_loadingRoutes) {
//       return const Center(
//         child:
//         CircularProgressIndicator(),
//       );
//     }
//
//     return Stack(
//       children: [
//         _trackingRoutes.isEmpty
//             ? const Center(
//           child: Text(
//             'No bus routes being tracked.',
//             style: TextStyle(
//               fontSize: 16,
//             ),
//           ),
//         )
//             : ListView.builder(
//           padding:
//           const EdgeInsets.fromLTRB(
//             12,
//             12,
//             12,
//             90,
//           ),
//           itemCount:
//           _trackingRoutes.length,
//           itemBuilder:
//               (context, index) {
//             final route =
//             _trackingRoutes[index];
//
//             return Card(
//               margin:
//               const EdgeInsets.only(
//                 bottom: 10,
//               ),
//               child: ListTile(
//                 leading:
//                 const CircleAvatar(
//                   child: Icon(
//                     Icons.directions_bus,
//                   ),
//                 ),
//                 title: Text(
//                   route.shortName,
//                   style:
//                   const TextStyle(
//                     fontWeight:
//                     FontWeight.bold,
//                   ),
//                 ),
//                 subtitle: Text(
//                   route.longName,
//                 ),
//                 trailing:
//                 Switch(
//                   value:
//                   _routeEnabled[
//                   route.id] ??
//                       false,
//                   onChanged:
//                       (value) async {
//                     setState(() {
//                       _routeEnabled[
//                       route.id] =
//                           value;
//                     });
//
//                     await _saveEnabledRoutes();
//                   },
//                 ),
//
//                 // ==================================================
//                 // LONG PRESS TO REMOVE
//                 // ==================================================
//
//                 onLongPress: () {
//                   _removeRoute(
//                     route,
//                   );
//                 },
//
//                 onTap: () {
//                   // Route configuration only.
//                   // Does not open MapScreen.
//                 },
//               ),
//             );
//           },
//         ),
//
//         Positioned(
//           right: 20,
//           bottom: 20,
//           child: FloatingActionButton(
//             onPressed:
//             _showAddRouteDialog,
//             child: const Icon(
//               Icons.add,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   // ============================================================
//   // NOTIFICATION TAB
//   // ============================================================
//
//   Widget _buildNotificationTab() {
//     return const Center(
//       child: Text(
//         'No bus notifications.',
//         style: TextStyle(
//           fontSize: 16,
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

import '../models/route.dart';
import '../services/gtfs_static_service.dart';
import '../services/route_preferences_service.dart';

class BusScreen extends StatefulWidget {
  const BusScreen({super.key});

  @override
  State<BusScreen> createState() => _BusScreenState();
}

class _BusScreenState extends State<BusScreen> {
  final GtfsStaticService _gtfsService =
  GtfsStaticService(
    directory: 'assets/gtfs',
  );

  final List<GtfsRoute> _trackingRoutes = [];

  final Map<String, bool> _routeEnabled = {};

  List<GtfsRoute> _availableRoutes = [];

  bool _loadingRoutes = true;

  @override
  void initState() {
    super.initState();

    _loadRoutes();
  }

  // ============================================================
  // LOAD ROUTES
  // ============================================================

  Future<void> _loadRoutes() async {
    try {
      final routes =
      await _gtfsService.getRoutes();

      final savedRouteIds =
      await RoutePreferencesService
          .getBusRoutes();

      final enabledRouteIds =
      await RoutePreferencesService
          .getEnabledBusRoutes();

      final availableRoutes = routes
          .where(
            (route) => route.type == 3,
      )
          .toList();

      final trackingRoutes = availableRoutes
          .where(
            (route) =>
            savedRouteIds.contains(route.id),
      )
          .toList();

      final enabled = <String, bool>{};

      for (final route in trackingRoutes) {
        enabled[route.id] =
            enabledRouteIds.contains(route.id);
      }

      if (!mounted) return;

      setState(() {
        _availableRoutes =
            availableRoutes;

        _trackingRoutes.clear();
        _trackingRoutes.addAll(
          trackingRoutes,
        );

        _routeEnabled.clear();
        _routeEnabled.addAll(
          enabled,
        );

        _loadingRoutes = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingRoutes = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load bus routes: $e',
          ),
        ),
      );

      print(
        'Failed to load bus routes: $e',
      );
    }
  }

  // ============================================================
  // SAVE ALL BUS PREFERENCES
  // ============================================================

  Future<void> _savePreferences() async {
    final trackedRouteIds =
    _trackingRoutes
        .map(
          (route) => route.id,
    )
        .toList();

    final enabledRouteIds =
    _trackingRoutes
        .where(
          (route) =>
      _routeEnabled[route.id] ==
          true,
    )
        .map(
          (route) => route.id,
    )
        .toList();

    await RoutePreferencesService
        .saveBusPreferences(
      trackedRouteIds:
      trackedRouteIds,
      enabledRouteIds:
      enabledRouteIds,
    );
  }

  // ============================================================
  // REMOVE ROUTE
  // ============================================================

  Future<void> _removeRoute(
      GtfsRoute route,
      ) async {
    final bool? confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove Bus Route?',
          ),
          content: Text(
            'Are you sure you want to remove '
                'route ${route.shortName} '
                'from your tracked buses?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _trackingRoutes.removeWhere(
            (existing) =>
        existing.id == route.id,
      );

      _routeEnabled.remove(
        route.id,
      );
    });

    await _savePreferences();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          'Route ${route.shortName} removed.',
        ),
      ),
    );
  }

  // ============================================================
  // ADD ROUTE
  // ============================================================

  void _showAddRouteDialog() {
    if (_availableRoutes.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No bus routes available.',
          ),
        ),
      );

      return;
    }

    final routes = _availableRoutes
        .where(
          (route) => !_trackingRoutes.any(
            (existing) =>
        existing.id == route.id,
      ),
    )
        .toList();

    if (routes.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'All bus routes have already been added.',
          ),
        ),
      );

      return;
    }

    GtfsRoute? selectedRoute =
        routes.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                'Add Bus Route',
              ),
              content:
              DropdownButtonFormField<
                  GtfsRoute>(
                value: selectedRoute,
                isExpanded: true,
                decoration:
                const InputDecoration(
                  labelText: 'Bus Route',
                  border:
                  OutlineInputBorder(),
                ),
                items: routes.map(
                      (route) {
                    return DropdownMenuItem<
                        GtfsRoute>(
                      value: route,
                      child: Text(
                        route.shortName,
                        overflow:
                        TextOverflow
                            .ellipsis,
                      ),
                    );
                  },
                ).toList(),
                onChanged: (route) {
                  setDialogState(() {
                    selectedRoute =
                        route;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child: const Text(
                    'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed:
                  selectedRoute == null
                      ? null
                      : () async {
                    final route =
                    selectedRoute!;

                    setState(() {
                      _trackingRoutes
                          .add(route);

                      _routeEnabled[
                      route.id] =
                      true;
                    });

                    await _savePreferences();

                    if (!context
                        .mounted) {
                      return;
                    }

                    Navigator.pop(
                      context,
                    );
                  },
                  child: const Text(
                    'Confirm',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bus'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(
                  Icons.directions_bus,
                ),
                text: 'Track Bus',
              ),
              Tab(
                icon: Icon(
                  Icons.notifications,
                ),
                text: 'Notification',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTrackBusTab(),
            _buildNotificationTab(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TRACK BUS TAB
  // ============================================================

  Widget _buildTrackBusTab() {
    if (_loadingRoutes) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    return Stack(
      children: [
        _trackingRoutes.isEmpty
            ? const Center(
          child: Text(
            'No bus routes being tracked.',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        )
            : ListView.builder(
          padding:
          const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            90,
          ),
          itemCount:
          _trackingRoutes.length,
          itemBuilder:
              (context, index) {
            final route =
            _trackingRoutes[index];

            return Card(
              margin:
              const EdgeInsets.only(
                bottom: 10,
              ),
              child: ListTile(
                leading:
                const CircleAvatar(
                  child: Icon(
                    Icons.directions_bus,
                  ),
                ),
                title: Text(
                  route.shortName,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  route.longName,
                ),
                trailing:
                Switch(
                  value:
                  _routeEnabled[
                  route.id] ??
                      false,
                  onChanged:
                      (value) async {
                    setState(() {
                      _routeEnabled[
                      route.id] =
                          value;
                    });

                    await _savePreferences();
                  },
                ),

                // Hold the row to remove it.
                onLongPress: () {
                  _removeRoute(
                    route,
                  );
                },

                onTap: () {
                  // Route configuration only.
                },
              ),
            );
          },
        ),

        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed:
            _showAddRouteDialog,
            child: const Icon(
              Icons.add,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NOTIFICATION TAB
  // ============================================================

  Widget _buildNotificationTab() {
    return const Center(
      child: Text(
        'No bus notifications.',
        style: TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }
}
