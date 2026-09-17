import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/otp_itinerary.dart';
import '../services/nominatim_service.dart';
import '../services/otp_service.dart';

class RoutePlannerScreen extends StatefulWidget {
  const RoutePlannerScreen({super.key});

  @override
  State<RoutePlannerScreen> createState() =>
      _RoutePlannerScreenState();
}

class _RoutePlannerScreenState
    extends State<RoutePlannerScreen> {
  final MapController _mapController =
  MapController();

  final TextEditingController _fromController =
  TextEditingController();

  final TextEditingController _toController =
  TextEditingController();

  final NominatimService _nominatimService =
  NominatimService();

  final OtpService _otpService =
  OtpService();

  LatLng? _fromLocation;
  LatLng? _toLocation;

  String? _activeField;

  bool _searching = false;
  bool _planning = false;

  List<OtpItinerary> _itineraries = [];

  // Decoded OTP route geometry.
  List<List<LatLng>> _routePoints = [];

  final LatLng _defaultCenter =
  const LatLng(3.1569, 101.7147);

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Coordinate input
  // Example:
  // 3.1569, 101.7147
  // ------------------------------------------------------------

  LatLng? _parseCoordinates(String text) {
    final parts = text.trim().split(',');

    if (parts.length != 2) {
      return null;
    }

    final latitude =
    double.tryParse(parts[0].trim());

    final longitude =
    double.tryParse(parts[1].trim());

    if (latitude == null || longitude == null) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(
      latitude,
      longitude,
    );
  }

  // ------------------------------------------------------------
  // Search location using Nominatim
  // ------------------------------------------------------------

  Future<void> _searchLocation(
      String field,
      String text,
      ) async {
    final query = text.trim();

    if (query.isEmpty) {
      _showMessage(
        'Please enter a location.',
      );
      return;
    }

    // Coordinates do not need Nominatim.
    final coordinates = _parseCoordinates(query);

    if (coordinates != null) {
      _setLocation(
        field,
        coordinates,
        query,
      );

      return;
    }

    setState(() {
      _searching = true;
    });

    try {
      final results =
      await _nominatimService.search(query);

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        _showMessage(
          'No locations found for "$query".',
        );
        return;
      }

      if (results.length == 1) {
        _selectNominatimResult(
          field,
          results.first,
        );
        return;
      }

      final selected =
      await showModalBottomSheet<NominatimResult>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(
                bottom: 16,
              ),
              itemCount: results.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1),
              itemBuilder: (
                  context,
                  index,
                  ) {
                final result = results[index];

                return ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                  ),
                  title: Text(
                    result.displayName,
                    maxLines: 3,
                    overflow:
                    TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                      result,
                    );
                  },
                );
              },
            ),
          );
        },
      );

      if (!mounted || selected == null) {
        return;
      }

      _selectNominatimResult(
        field,
        selected,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Could not search for this location.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // Select Nominatim result
  // ------------------------------------------------------------

  void _selectNominatimResult(
      String field,
      NominatimResult result,
      ) {
    _setLocation(
      field,
      result.location,
      result.displayName,
    );
  }

  // ------------------------------------------------------------
  // Set From / To location
  // ------------------------------------------------------------

  void _setLocation(
      String field,
      LatLng location,
      String displayText,
      ) {
    setState(() {
      if (field == 'from') {
        _fromLocation = location;
        _fromController.text = displayText;
      } else {
        _toLocation = location;
        _toController.text = displayText;
      }

      _activeField = null;

      // A new location invalidates the
      // previously calculated route.
      _itineraries.clear();
      _routePoints.clear();
    });

    _mapController.move(
      location,
      15,
    );
  }

  // ------------------------------------------------------------
  // Long press map
  // ------------------------------------------------------------

  void _handleMapLongPress(
      TapPosition tapPosition,
      LatLng location,
      ) {
    if (_activeField == null) {
      _showMessage(
        'Tap From or To first, then long-press the map.',
      );
      return;
    }

    final coordinateText =
        '${location.latitude.toStringAsFixed(6)}, '
        '${location.longitude.toStringAsFixed(6)}';

    _setLocation(
      _activeField!,
      location,
      coordinateText,
    );
  }

  // ------------------------------------------------------------
  // Current location
  // ------------------------------------------------------------

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage(
          'Please enable location services.',
        );
        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        _showMessage(
          'Location permission is required.',
        );
        return;
      }

      final position =
      await Geolocator.getCurrentPosition(
        desiredAccuracy:
        LocationAccuracy.high,
      );

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      _setLocation(
        'from',
        location,
        '${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}',
      );
    } catch (e) {
      _showMessage(
        'Could not get your current location.',
      );
    }
  }

  // ------------------------------------------------------------
  // Plan Journey
  // ------------------------------------------------------------

  Future<void> _planJourney() async {
    if (_fromLocation == null) {
      _showMessage(
        'Please set your starting location.',
      );
      return;
    }

    if (_toLocation == null) {
      _showMessage(
        'Please set your destination.',
      );
      return;
    }

    setState(() {
      _planning = true;
      _itineraries.clear();
      _routePoints.clear();
    });

    try {
      final results =
      await _otpService.planJourney(
        from: _fromLocation!,
        to: _toLocation!,
      );

      if (!mounted) {
        return;
      }

      if (results.isEmpty) {
        setState(() {
          _planning = false;
        });

        _showMessage(
          'No public transport routes found.',
        );

        return;
      }

      // ----------------------------------------------------
      // Keep only routes with at least one public
      // transport leg.
      // ----------------------------------------------------

      final transitRoutes = results.where(
            (itinerary) {
          return itinerary.legs.any(
                (leg) => leg.isTransit,
          );
        },
      ).toList();

      if (transitRoutes.isEmpty) {
        setState(() {
          _planning = false;
        });

        _showMessage(
          'No public transport routes found.',
        );

        return;
      }

      // ----------------------------------------------------
      // Remove exact duplicate itineraries.
      // ----------------------------------------------------

      final List<OtpItinerary> filteredRoutes = [];

      for (final itinerary in transitRoutes) {
        bool duplicate = false;

        for (final existing in filteredRoutes) {
          if (itinerary.legs.length !=
              existing.legs.length) {
            continue;
          }

          bool sameRoute = true;

          for (int i = 0;
          i < itinerary.legs.length;
          i++) {
            final currentLeg =
            itinerary.legs[i];

            final existingLeg =
            existing.legs[i];

            if (currentLeg.mode !=
                existingLeg.mode ||
                currentLeg.routeId !=
                    existingLeg.routeId ||
                currentLeg.fromName !=
                    existingLeg.fromName ||
                currentLeg.toName !=
                    existingLeg.toName) {
              sameRoute = false;
              break;
            }
          }

          if (sameRoute) {
            duplicate = true;
            break;
          }
        }

        if (!duplicate) {
          filteredRoutes.add(
            itinerary,
          );
        }
      }

      // ----------------------------------------------------
      // Sort by total walking distance.
      // ----------------------------------------------------

      filteredRoutes.sort(
            (a, b) {
          double walkingA = 0;
          double walkingB = 0;

          for (final leg in a.legs) {
            if (leg.mode == 'WALK') {
              walkingA += leg.distance;
            }
          }

          for (final leg in b.legs) {
            if (leg.mode == 'WALK') {
              walkingB += leg.distance;
            }
          }

          return walkingA.compareTo(walkingB);
        },
      );

      // ----------------------------------------------------
      // Decode geometry for every route.
      // ----------------------------------------------------

      final List<List<LatLng>> decodedRoutes = [];

      for (final itinerary in filteredRoutes) {
        for (final leg in itinerary.legs) {
          if (leg.geometry == null ||
              leg.geometry!.isEmpty) {
            continue;
          }

          final points = _decodePolyline(
            leg.geometry!,
          );

          if (points.length >= 2) {
            decodedRoutes.add(points);
          }
        }
      }

      setState(() {
        _itineraries = filteredRoutes;
        _routePoints = decodedRoutes;
        _planning = false;
      });

      if (_routePoints.isNotEmpty) {
        _fitRouteOnMap(
          _routePoints,
        );
      } else {
        _showMessage(
          'Routes were found, but no map geometry was returned.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _planning = false;
      });

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Route Planning Failed',
            ),
            content: SingleChildScrollView(
              child: SelectableText(
                e.toString(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // ------------------------------------------------------------
  // Decode OTP encoded polyline
  // ------------------------------------------------------------

  List<LatLng> _decodePolyline(
      String encoded,
      ) {
    final List<LatLng> points = [];

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      while (true) {
        if (index >= encoded.length) {
          return points;
        }

        final int byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final int latitudeChange =
      (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      latitude += latitudeChange;

      shift = 0;
      result = 0;

      while (true) {
        if (index >= encoded.length) {
          return points;
        }

        final int byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final int longitudeChange =
      (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      longitude += longitudeChange;

      points.add(
        LatLng(
          latitude / 100000.0,
          longitude / 100000.0,
        ),
      );
    }

    return points;
  }

  // ------------------------------------------------------------
  // Fit map to route
  // ------------------------------------------------------------

  void _fitRouteOnMap(
      List<List<LatLng>> routes,
      ) {
    final List<LatLng> allPoints = [];

    for (final route in routes) {
      allPoints.addAll(route);
    }

    if (allPoints.isEmpty) {
      return;
    }

    double minLat =
        allPoints.first.latitude;

    double maxLat =
        allPoints.first.latitude;

    double minLon =
        allPoints.first.longitude;

    double maxLon =
        allPoints.first.longitude;

    for (final point in allPoints) {
      minLat = math.min(
        minLat,
        point.latitude,
      );

      maxLat = math.max(
        maxLat,
        point.latitude,
      );

      minLon = math.min(
        minLon,
        point.longitude,
      );

      maxLon = math.max(
        maxLon,
        point.longitude,
      );
    }

    final bounds = LatLngBounds(
      LatLng(
        minLat,
        minLon,
      ),
      LatLng(
        maxLat,
        maxLon,
      ),
    );

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    });
  }

  // ------------------------------------------------------------
  // Route polylines
  // ------------------------------------------------------------

  List<Polyline> _buildRoutePolylines() {
    final List<Polyline> polylines = [];

    for (int i = 0;
    i < _routePoints.length;
    i++) {
      polylines.add(
        Polyline(
          points: _routePoints[i],
          strokeWidth: 6,
          color: _getRouteColor(i),
        ),
      );
    }

    return polylines;
  }

  Color _getRouteColor(
      int index,
      ) {
    const colors = [
      Colors.grey,
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    return colors[
    index % colors.length];
  }

  // ------------------------------------------------------------
  // Show message
  // ------------------------------------------------------------

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration:
          const Duration(seconds: 2),
        ),
      );
  }

  // ------------------------------------------------------------
  // Input field
  // ------------------------------------------------------------

  Widget _buildLocationField({
    required String field,
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool showCurrentLocation = false,
  }) {
    final isActive =
        _activeField == field;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? Theme.of(context)
              .colorScheme
              .primary
              : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(0, 2),
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),

          Icon(
            icon,
            size: 21,
            color: isActive
                ? Theme.of(context)
                .colorScheme
                .primary
                : Colors.grey.shade700,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: TextField(
              controller: controller,
              textInputAction:
              TextInputAction.search,
              keyboardType:
              TextInputType.text,
              maxLines: 1,
              textAlignVertical:
              TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 14,
              ),
              decoration:
              const InputDecoration(
                hintText: 'Location',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                EdgeInsets.symmetric(
                  vertical: 0,
                ),
              ).copyWith(
                hintText: label,
              ),
              onTap: () {
                setState(() {
                  _activeField = field;
                });
              },
              onChanged: (_) {
                if (field == 'from') {
                  _fromLocation = null;
                } else {
                  _toLocation = null;
                }

                _itineraries.clear();
                _routePoints.clear();

                setState(() {});
              },
              onSubmitted: (value) {
                _searchLocation(
                  field,
                  value,
                );
              },
            ),
          ),

          if (showCurrentLocation)
            IconButton(
              tooltip:
              'Use current location',
              padding: EdgeInsets.zero,
              constraints:
              const BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
              icon: const Icon(
                Icons.my_location,
                size: 20,
              ),
              onPressed:
              _useCurrentLocation,
            ),

          IconButton(
            tooltip:
            'Search location',
            padding: EdgeInsets.zero,
            constraints:
            const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: _searching
                ? const SizedBox(
              width: 18,
              height: 18,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(
              Icons.search,
              size: 21,
            ),
            onPressed: _searching
                ? null
                : () {
              _searchLocation(
                field,
                controller.text,
              );
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Itinerary card
  // ------------------------------------------------------------

  Widget _buildItineraryCard(
      OtpItinerary itinerary,
      ) {
    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.route,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Route',
                  style:
                  Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTotalDuration(
                    itinerary,
                  ),
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...itinerary.legs.map(
              _buildLeg,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Itinerary leg
  // ------------------------------------------------------------

  Widget _buildLeg(
      OtpLeg leg,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            leg.modeIcon,
            style:
            const TextStyle(
              fontSize: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      leg.displayMode,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    if (leg.routeShortName !=
                        null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration:
                        BoxDecoration(
                          color: Colors.blue
                              .withOpacity(
                            0.1,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            5,
                          ),
                        ),
                        child: Text(
                          leg.routeShortName!,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${leg.fromName} → ${leg.toName}',
                  style:
                  const TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${leg.durationText}'
                      '${leg.distance > 0 ? ' • ${leg.distance.round()} m' : ''}',
                  style:
                  TextStyle(
                    color:
                    Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                if (leg.routeLongName !=
                    null &&
                    leg.routeLongName!
                        .isNotEmpty)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      top: 3,
                    ),
                    child: Text(
                      leg.routeLongName!,
                      style:
                      TextStyle(
                        color:
                        Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // Total duration
  // ------------------------------------------------------------

  String _formatTotalDuration(
      OtpItinerary itinerary,
      ) {
    final totalSeconds =
        itinerary.totalDuration;

    final minutes =
    (totalSeconds / 60).round();

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours =
        minutes ~/ 60;

    final remaining =
        minutes % 60;

    if (remaining == 0) {
      return '${hours}h';
    }

    return '${hours}h ${remaining}m';
  }

  // ------------------------------------------------------------
  // Build
  // ------------------------------------------------------------

  @override
  Widget build(
      BuildContext context,
      ) {
    final markers = <Marker>[];

    if (_fromLocation != null) {
      markers.add(
        Marker(
          point: _fromLocation!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.location_on,
            size: 42,
            color: Colors.green,
          ),
        ),
      );
    }

    if (_toLocation != null) {
      markers.add(
        Marker(
          point: _toLocation!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.location_on,
            size: 42,
            color: Colors.red,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Plan Journey',
        ),
      ),
      body: Stack(
        children: [
          // ----------------------------------------------------
          // Map
          // ----------------------------------------------------

          FlutterMap(
            mapController:
            _mapController,
            options: MapOptions(
              initialCenter:
              _defaultCenter,
              initialZoom: 13,
              onLongPress:
              _handleMapLongPress,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/'
                    '{z}/{x}/{y}.png',
                userAgentPackageName:
                'com.example.trackerapp',
              ),

              // OTP route lines.
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines:
                  _buildRoutePolylines(),
                ),

              MarkerLayer(
                markers: markers,
              ),

              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),

          // ----------------------------------------------------
          // Search box
          // ----------------------------------------------------

          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 5,
              shape:
              RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Padding(
                padding:
                const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    _buildLocationField(
                      field: 'from',
                      label: 'From',
                      controller:
                      _fromController,
                      icon:
                      Icons.trip_origin,
                      showCurrentLocation:
                      true,
                    ),

                    const SizedBox(height: 6),

                    _buildLocationField(
                      field: 'to',
                      label: 'To',
                      controller:
                      _toController,
                      icon:
                      Icons.location_on,
                    ),

                    const SizedBox(height: 7),

                    SizedBox(
                      height: 38,
                      width: double.infinity,
                      child:
                      ElevatedButton.icon(
                        onPressed: _planning
                            ? null
                            : _planJourney,
                        icon: _planning
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.route,
                          size: 19,
                        ),
                        label: Text(
                          _planning
                              ? 'Finding routes...'
                              : 'Plan Journey',
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Tap From or To, then long-press the map '
                          'to select a location.',
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

// ----------------------------------------------------
// Route results
// ----------------------------------------------------

          AnimatedPositioned(
            duration: const Duration(
              milliseconds: 350,
            ),
            curve: Curves.easeOut,
            left: 10,
            right: 10,
            bottom: _itineraries.isNotEmpty
                ? 10
                : -320,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 300,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(
                  12,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withOpacity(
                      0.2,
                    ),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Panel handle.
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8,
                      bottom: 4,
                    ),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      4,
                      8,
                      8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.route,
                          size: 22,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            '${_itineraries.length} routes found',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(
                            Icons.close,
                          ),
                          onPressed: () {
                            setState(() {
                              _itineraries.clear();
                              _routePoints.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(
                    height: 1,
                  ),

                  // Route list.
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(
                        10,
                      ),
                      itemCount: _itineraries.length,
                      itemBuilder: (
                          context,
                          index,
                          ) {
                        return _buildItineraryCard(
                          _itineraries[index],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------
          // OpenStreetMap attribution
          // ----------------------------------------------------

          Positioned(
            bottom: 5,
            left: 5,
            child: Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              color: Colors.white70,
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}