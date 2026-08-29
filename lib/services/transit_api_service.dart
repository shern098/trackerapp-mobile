// TODO: Replace the mock lookups below with a real call to Malaysia's
// official Open API (https://developer.data.gov.my/realtime-api/gtfs-static).
// That feed returns a GTFS zip (routes.txt, stops.txt, stop_times.txt, shapes.txt)
// rather than simple JSON, so unlike Practical 10's Weather API, you'll need to:
//   1. Download & unzip the feed (rapid-bus-kl for buses, rapid-rail-kl for trains)
//   2. Parse the relevant CSVs with the `csv` package
//   3. Filter to the route_id/route_short_name the user typed
// For now this service returns hardcoded info for bus 300 and the Kelana Jaya
// line (matching your wireframe) so the rest of the app is fully testable.

class RouteInfo {
  final String label;
  final int stops;
  final int tripDurationMinutes;
  final List<String> stopNames;

  RouteInfo({
    required this.label,
    required this.stops,
    required this.tripDurationMinutes,
    required this.stopNames,
  });
}

class TransitApiService {
  static final Map<String, RouteInfo> _mockBusRoutes = {
    '300': RouteInfo(
      label: '300',
      stops: 46,
      tripDurationMinutes: 40,
      stopNames: ['Putrajaya Sentral', 'Hospital Putrajaya', '...'],
    ),
  };

  static final Map<String, RouteInfo> _mockTrainRoutes = {
    'kelana jaya': RouteInfo(
      label: 'Kelana Jaya',
      stops: 46,
      tripDurationMinutes: 120,
      stopNames: ['Putrajaya Sentral', 'Hospital Putrajaya', '...'],
    ),
  };

  Future<RouteInfo?> fetchBusInfo(String busNumber) async {
    try {
      // Simulated network delay, same shape as a real http.get call
      await Future.delayed(const Duration(milliseconds: 400));
      return _mockBusRoutes[busNumber.trim()];
    } catch (e) {
      throw Exception('Error fetching bus info : $e');
    }
  }

  Future<RouteInfo?> fetchTrainInfo(String lineName) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      return _mockTrainRoutes[lineName.trim().toLowerCase()];
    } catch (e) {
      throw Exception('Error fetching train info : $e');
    }
  }
}
