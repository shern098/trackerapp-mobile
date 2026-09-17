import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../models/vehicle.dart';
import '../models/route.dart';
import '../models/bus_stop.dart';

import '../services/transport_api.dart';
import '../services/gtfs_static_service.dart';
import '../services/route_preferences_service.dart';

import '../widgets/vehicle_marker.dart';
import '../widgets/route_layer.dart';
import '../widgets/bus_stop_marker.dart';
import '../widgets/bus_stop_popup.dart';
import '../widgets/app_drawer.dart';
import '../widgets/vehicle_popup.dart';

class MapScreen extends StatefulWidget {
  final String? routeId;

  const MapScreen({
    super.key,
    this.routeId,
  });

  @override
  State<MapScreen> createState() =>
      _MapScreenState();
}

class _MapScreenState
    extends State<MapScreen> {
  late final MapController _mapController;

  final TransportApi _transportApi =
  TransportApi();

  final GtfsStaticService _gtfsService =
  GtfsStaticService(
    directory: 'assets/gtfs',
  );

  LatLng _center =
  const LatLng(
    3.1569,
    101.7147,
  );

  LatLng? _currentUserLocation;

  List<Vehicle> _vehicles = [];

  Timer? _timer;

  StreamSubscription<Position>? _locationSubscription;

  // ============================================================
  // ROUTE DATA
  // ============================================================

  // Route ID -> route.
  final Map<String, GtfsRoute>
  _selectedRoutes = {};

  // Route ID -> route shapes.
  final Map<String, List<List<LatLng>>>
  _selectedRoutePoints = {};

  // Route ID -> stops belonging to that route.
  //
  // This lets us remove one route's stops without
  // rereading the GTFS files.
  final Map<String, List<BusStop>>
  _routeBusStops = {};

  // All bus stops currently displayed.
  List<BusStop> _busStops = [];

  // Stop ID -> human-readable route number.
  final Map<String, String>
  _busStopRouteNames = {};

  BusStop? _selectedBusStop;
  Vehicle? _selectedVehicle;

  bool _loadingRoute = false;

  // Prevent multiple preference syncs from
  // running at the same time.
  bool _syncingRoutes = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _mapController =
        MapController();

    RoutePreferencesService.changes
        .addListener(
      _onRoutePreferencesChanged,
    );

    _fetchRealtimeData();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        _fetchRealtimeData();
      },
    );

    _syncConfiguredRoutes();

    // Keep support for manually opening
    // a specific route.
    if (widget.routeId != null) {
      _selectRoute(
        widget.routeId!,
      );
    }
  }

  // ============================================================
  // ROUTE PREFERENCE CHANGED
  // ============================================================

  void _onRoutePreferencesChanged() {
    print('');
    print(
      'Route preferences changed.',
    );

    _syncConfiguredRoutes();
  }

  // ============================================================
  // SYNC CONFIGURED ROUTES
  // ============================================================
  //
  // IMPORTANT:
  //
  // This does NOT reload every route.
  //
  // OFF:
  //   Remove route from memory.
  //
  // ON:
  //   Load only that route.
  //
  // Existing enabled routes are left alone.
  // ============================================================

  Future<void>
  _syncConfiguredRoutes() async {
    if (_syncingRoutes) {
      return;
    }

    _syncingRoutes = true;

    try {
      final enabledBusRoutes =
      await RoutePreferencesService
          .getEnabledBusRoutes();

      final enabledTrainRoutes =
      await RoutePreferencesService
          .getEnabledTrainRoutes();

      final desiredRouteIds =
      <String>{
        ...enabledBusRoutes,
        ...enabledTrainRoutes,
      };

      print('');
      print(
        '========== ROUTE SYNC ==========',
      );
      print(
        'Enabled routes: '
            '$desiredRouteIds',
      );
      print(
        'Currently loaded: '
            '${_selectedRoutes.keys.toList()}',
      );

      // ========================================================
      // REMOVE DISABLED ROUTES
      // ========================================================

      final currentlyLoadedIds =
      _selectedRoutes.keys.toList();

      for (final routeId
      in currentlyLoadedIds) {
        if (!desiredRouteIds.contains(
          routeId,
        )) {
          print(
            'Removing route from map: '
                '$routeId',
          );

          _removeRouteFromMap(
            routeId,
          );
        }
      }

      // ========================================================
      // LOAD ONLY NEWLY ENABLED ROUTES
      // ========================================================

      final currentIds =
      _selectedRoutes.keys.toSet();

      final routesToLoad =
      desiredRouteIds
          .difference(currentIds);

      print(
        'Routes that need loading: '
            '$routesToLoad',
      );

      for (final routeId
      in routesToLoad) {
        await _selectRoute(
          routeId,
          clearExisting: false,
        );
      }

      print(
        '================================',
      );
    } catch (e) {
      print(
        'Failed to sync configured routes: '
            '$e',
      );
    } finally {
      _syncingRoutes = false;
    }
  }

  // ============================================================
  // REMOVE ROUTE FROM MAP MEMORY
  // ============================================================

  void _removeRouteFromMap(
      String routeId,
      ) {
    if (!mounted) return;

    setState(() {
      _selectedRoutes.remove(
        routeId,
      );

      _selectedRoutePoints.remove(
        routeId,
      );

      _routeBusStops.remove(
        routeId,
      );

      _rebuildBusStops();
    });

    print(
      'Route removed from map memory: '
          '$routeId',
    );
  }

  // ============================================================
  // REBUILD BUS STOP LIST FROM MEMORY
  // ============================================================

  void _rebuildBusStops() {
    final List<BusStop> allStops = [];

    final Map<String, String>
    routeNames = {};

    for (final entry
    in _routeBusStops.entries) {
      final routeId =
          entry.key;

      final stops =
          entry.value;

      final route =
      _selectedRoutes[routeId];

      if (route == null) {
        continue;
      }

      for (final stop in stops) {
        if (!allStops.any(
              (existing) =>
          existing.id == stop.id,
        )) {
          allStops.add(stop);
        }

        routeNames[stop.id] =
            route.shortName;
      }
    }

    _busStops = allStops;

    _busStopRouteNames.clear();

    _busStopRouteNames.addAll(
      routeNames,
    );

    // Close popup if its stop no longer exists.
    if (_selectedBusStop != null) {
      final stillExists =
      _busStops.any(
            (stop) =>
        stop.id ==
            _selectedBusStop!.id,
      );

      if (!stillExists) {
        _selectedBusStop = null;
      }
    }


  }




  // ============================================================
  // REALTIME VEHICLE DATA
  // ============================================================

  Future<void> _fetchRealtimeData() async {
    try {
      final enabledBusRoutes =
      await RoutePreferencesService
          .getEnabledBusRoutes();

      print('');
      print('========== REALTIME BUS DATA ==========');
      print(
        'Enabled bus routes: $enabledBusRoutes',
      );

      if (enabledBusRoutes.isEmpty) {
        print('No enabled bus routes.');

        if (!mounted) return;

        setState(() {
          _vehicles = [];
        });

        return;
      }

      final List<Vehicle> allVehicles = [];

      for (final routeId in enabledBusRoutes) {
        print('');
        print(
          'Fetching live buses for route: $routeId',
        );

        final vehicles =
        await _transportApi.fetchVehicles(
          fallbackRoute: routeId,
        );

        print(
          'Vehicles received for $routeId: '
              '${vehicles.length}',
        );

        allVehicles.addAll(vehicles);
      }

      print(
        'Total live vehicles: '
            '${allVehicles.length}',
      );

      if (!mounted) return;

      setState(() {
        _vehicles = allVehicles;
      });

      print('========================================');
    } catch (e) {
      print(
        'Failed to fetch realtime vehicles: $e',
      );
    }
  }

  // ============================================================
  // LOAD ONE ROUTE
  // ============================================================

  Future<void> _selectRoute(
      String routeId, {
        bool clearExisting = false,
      }) async {
    if (routeId.isEmpty) {
      return;
    }

    // Already loaded.
    if (_selectedRoutes.containsKey(
      routeId,
    )) {
      return;
    }

    print('');
    print(
      '========== LOADING ROUTE ==========',
    );
    print(
      'Route ID: $routeId',
    );

    if (!mounted) return;

    setState(() {
      _loadingRoute = true;

      if (clearExisting) {
        _selectedRoutes.clear();
        _selectedRoutePoints.clear();
        _routeBusStops.clear();
        _busStops = [];
        _busStopRouteNames.clear();
        _selectedBusStop = null;
      }
    });

    try {
      // --------------------------------------------------------
      // 1. Get route
      // --------------------------------------------------------

      final route =
      await _gtfsService.getRoute(
        routeId,
      );

      if (route == null) {
        throw Exception(
          'Route $routeId not found.',
        );
      }

      print(
        'Route ID: ${route.id}',
      );

      print(
        'Route number: '
            '${route.shortName}',
      );

      print(
        'Route name: '
            '${route.longName}',
      );

      // --------------------------------------------------------
      // 2. Get trips
      // --------------------------------------------------------

      final trips =
      await _gtfsService
          .getTripsForRoute(
        routeId,
      );

      if (trips.isEmpty) {
        throw Exception(
          'No trips found for $routeId.',
        );
      }

      print(
        'Trips found: '
            '${trips.length}',
      );

      // --------------------------------------------------------
      // 3. Get one trip for each direction
      // --------------------------------------------------------

      final Map<String, dynamic>
      directionTrips = {};

      for (final trip in trips) {
        if (!directionTrips
            .containsKey(
          trip.directionId,
        )) {
          directionTrips[
          trip.directionId] =
              trip;
        }
      }

      print(
        'Directions found: '
            '${directionTrips.length}',
      );

      // --------------------------------------------------------
      // 4. Load shapes and stops
      // --------------------------------------------------------

      final List<List<LatLng>>
      routePoints = [];

      final List<BusStop>
      routeStops = [];

      for (final entry
      in directionTrips.entries) {
        final trip =
            entry.value;

        print('');
        print(
          'Direction '
              '${trip.directionId}',
        );

        print(
          'Trip: '
              '${trip.tripId}',
        );

        print(
          'Shape: '
              '${trip.shapeId}',
        );

        print(
          'Headsign: '
              '${trip.headsign}',
        );

        // ------------------------------------------------------
        // Shape
        // ------------------------------------------------------

        final shape =
        await _gtfsService
            .getShape(
          trip.shapeId,
        );

        if (shape.isNotEmpty) {
          routePoints.add(
            shape
                .map(
                  (point) =>
              point.position,
            )
                .toList(),
          );
        }

        // ------------------------------------------------------
        // Stops
        // ------------------------------------------------------

        final stops =
        await _gtfsService
            .getStopsForTrip(
          trip.tripId,
        );

        for (final stop in stops) {
          if (!routeStops.any(
                (existing) =>
            existing.id ==
                stop.id,
          )) {
            routeStops.add(stop);
          }
        }
      }

      // --------------------------------------------------------
      // IMPORTANT:
      //
      // The user may have toggled this route OFF while the
      // GTFS data was loading.
      //
      // Check preferences before adding it to the map.
      // --------------------------------------------------------

      final enabledBusRoutes =
      await RoutePreferencesService
          .getEnabledBusRoutes();

      final enabledTrainRoutes =
      await RoutePreferencesService
          .getEnabledTrainRoutes();

      final stillEnabled =
          enabledBusRoutes.contains(
            routeId,
          ) ||
              enabledTrainRoutes.contains(
                routeId,
              );

      if (!stillEnabled &&
          widget.routeId != routeId) {
        print(
          'Route $routeId was disabled '
              'while loading. Not adding it.',
        );

        if (mounted) {
          setState(() {
            _loadingRoute = false;
          });
        }

        return;
      }

      // --------------------------------------------------------
      // 5. Save route into memory
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _selectedRoutes[
        route.id] =
            route;

        _selectedRoutePoints[
        route.id] =
            routePoints;

        _routeBusStops[
        route.id] =
            routeStops;

        _rebuildBusStops();

        _loadingRoute = false;
      });

      print('');
      print(
        'Route loaded successfully.',
      );

      print(
        'Route ID: '
            '${route.id}',
      );

      print(
        'Route number: '
            '${route.shortName}',
      );

      print(
        'Shapes loaded: '
            '${routePoints.length}',
      );

      print(
        'Stops loaded: '
            '${routeStops.length}',
      );

      print(
        'Total routes currently '
            'on map: '
            '${_selectedRoutes.length}',
      );

      print(
        '====================================',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingRoute = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load route '
                '$routeId: $e',
          ),
        ),
      );

      print(
        'Failed to load route '
            '$routeId: $e',
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    RoutePreferencesService.changes
        .removeListener(
      _onRoutePreferencesChanged,
    );

    _timer?.cancel();

    _locationSubscription?.cancel();

    _mapController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      drawer: const AppDrawer(),

      appBar: AppBar(
        title: const Text(
          'Transport Maps',
        ),
        backgroundColor:
        const Color(0xFF2F8D46),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(
                Icons.menu,
                color: Colors.white,
              ),
              onPressed: () {
                Scaffold.of(context)
                    .openDrawer();
              },
            );
          },
        ),
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController:
            _mapController,

            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,

              onTap: (
                  tapPosition,
                  point,
                  ) {
                if (_selectedBusStop !=
                    null) {
                  setState(() {
                    _selectedBusStop =
                    null;
                  });
                }
              },
            ),

            children: [
              // ==================================================
              // OPENSTREETMAP
              // ==================================================

              TileLayer(
                urlTemplate:
                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                'android/app/build.gradle.kts',
              ),

              // ==================================================
              // ROUTES
              // ==================================================

              ..._selectedRoutes.entries
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (entry) {
                  final index = entry.key;
                  final routeEntry = entry.value;

                  final routeId =
                      routeEntry.key;

                  final route =
                      routeEntry.value;

                  final points =
                      _selectedRoutePoints[
                      routeId] ??
                          [];

                  return RouteLayer(
                    key: ValueKey(
                      'route_$routeId',
                    ),
                    route: route,
                    points: points,
                    colorIndex: index,
                  );
                },
              ),

              // ==================================================
              // BUS STOP MARKERS
              // ==================================================

              if (_busStops.isNotEmpty)
                MarkerLayer(
                  markers:
                  _busStops.map(
                        (stop) {
                      return Marker(
                        key: ValueKey(
                          'stop_${stop.id}',
                        ),
                        point:
                        stop.position,
                        width: 20,
                        height: 20,
                        child:
                        BusStopMarker(
                          stopName:
                          stop.name,
                          onTap: () {
                            setState(() {
                              _selectedBusStop =
                                  stop;
                            });
                          },
                        ),
                      );
                    },
                  ).toList(),
                ),

              // ==================================================
              // BUS STOP POPUP
              // ==================================================

              if (_selectedBusStop !=
                  null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point:
                      _selectedBusStop!
                          .position,
                      width: 220,
                      height: 110,
                      alignment:
                      Alignment
                          .bottomCenter,
                      child:
                      Transform.translate(
                        offset:
                        const Offset(
                          0,
                          -120,
                        ),
                        child:
                        BusStopPopup(
                          stop:
                          _selectedBusStop!,
                          routeName:
                          _busStopRouteNames[
                          _selectedBusStop!
                              .id] ??
                              '',
                        ),
                      ),
                    ),
                  ],
                ),

              if (_currentUserLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentUserLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

              // ==================================================
              // REALTIME VEHICLES
              // ==================================================

              MarkerLayer(
                markers:
                _vehicles.map(
                      (vehicle) {
                    return Marker(
                      key: ValueKey(
                        vehicle.id,
                      ),
                      point:
                      vehicle.position,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () {
                      setState(() {
                        _selectedVehicle = vehicle;
                        _selectedBusStop = null;
                      });
                    },
                        child: VehicleMarker(
                        vehicle: vehicle,
                        color: RouteLayer.routeColors[
                        _selectedRoutes.keys
                            .toList()
                            .indexOf(vehicle.routeId) %
                        RouteLayer.routeColors.length
                        ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),

              if (_selectedVehicle != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point:
                      _selectedVehicle!.position,
                      width: 220,
                      height: 110,
                      alignment:
                      Alignment.bottomCenter,
                      child: Transform.translate(
                        offset:
                        const Offset(
                          0,
                          -120,
                        ),
                        child: VehiclePopup(
                          vehicle:
                          _selectedVehicle!,
                          routeName:
                          _selectedVehicle!.routeId,
                        ),
                      ),
                    ),
                  ],
                ),

            ],
          ),

          // ====================================================
          // LOADING INDICATOR
          // ====================================================

          if (_loadingRoute)
            const Positioned(
              top: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding:
                  EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'Loading routes...',
                      ),
                    ],
                  ),
                ),
              ),
            ),


        ],
      ),

      // ========================================================
      // CURRENT LOCATION BUTTON
      // ========================================================

      floatingActionButton:
      FloatingActionButton(
        onPressed:
        _getCurrentLocation,
        tooltip:
        'Get Location',
        backgroundColor:
        const Color(0xFF2F8D46),
        child: const Icon(
          Icons.my_location,
          color: Colors.white,
        ),
      ),
    );
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void>
  _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Location services are disabled.',
          ),
        ),
      );

      return;
    }

    permission =
    await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator
          .requestPermission();

      if (permission ==
          LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are denied.',
            ),
          ),
        );

        return;
      }
    }

    final Position position =
    await Geolocator.getCurrentPosition();

    final location = LatLng(
      position.latitude,
      position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _center = location;
      _currentUserLocation = location;
    });

    _mapController.move(
      location,
      13.0,
    );

    _locationSubscription?.cancel();

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings:
          const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
              (Position position) {
            final location = LatLng(
              position.latitude,
              position.longitude,
            );

            if (!mounted) return;

            setState(() {
              _currentUserLocation = location;
            });
          },
        );
  }
}