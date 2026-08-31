import 'package:flutter/material.dart';
import '../main.dart' show currentUserNotifier;
import '../services/database_service.dart';
import '../services/transit_api_service.dart';

/// Lets the user type a bus number, look up its static schedule info
/// (via TransitApiService), review it, then save it into the "Buses"
/// table so it starts appearing in Bus List and can be tracked on the map.
/// Only reachable while signed in — BusListScreen gates navigation here,
/// and _addToBusList() double-checks in case this screen is ever reached
/// another way.
class AddBusScreen extends StatefulWidget {
  const AddBusScreen({super.key});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  // Captured from Autocomplete's fieldViewBuilder below — using its own
  // controller directly (rather than mirroring into a separate one) avoids
  // needing an addListener callback that would otherwise re-attach itself
  // on every rebuild.
  TextEditingController? _busNumberController;
  final _apiService = TransitApiService();
  final _dbService = DatabaseService();

  RouteInfo? _routeInfo;
  bool _isLoading = false;
  String? _errorText;
  List<String> _allBusNumbers = []; // powers the Autocomplete suggestions below

  @override
  void initState() {
    super.initState();
    _loadBusNumberSuggestions();
  }

  // NOTE: no dispose() override needed here — _busNumberController is
  // Autocomplete's own internally-created controller (we never called
  // TextEditingController() ourselves), so Autocomplete disposes it
  // automatically. Calling .dispose() on it ourselves too would crash
  // with "used after being disposed".

  // Loads every known bus number once when the screen opens, so
  // Autocomplete has something to filter against as the user types —
  // e.g. typing "3" suggests every bus number containing "3".
  void _loadBusNumberSuggestions() async {
    final numbers = await _apiService.listBusNumbers();
    if (mounted) setState(() => _allBusNumbers = numbers);
  }

  // Calls TransitApiService to fetch schedule info for whatever the user
  // typed. Errors are caught and shown inline rather than crashing the
  // screen — same try/catch shape as Practical 10's Weather API fetch.
  void _lookupBus() async {
    final input = _busNumberController?.text.trim() ?? '';
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _routeInfo = null;
    });

    try {
      final info = await _apiService.fetchBusInfo(input);
      setState(() {
        _routeInfo = info;
        _isLoading = false;
        if (info == null) _errorText = 'No route found for "$input".';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'Error: $e';
      });
    }
  }

  // Only called once a successful lookup has populated _routeInfo — saves
  // the bus number into SQLite, tagged to whoever is currently signed in,
  // and returns to Bus List.
  void _addToBusList() async {
    if (_routeInfo == null) return;

    final userId = currentUserNotifier.value?.id;
    if (userId == null) {
      // Shouldn't normally happen — BusListScreen only lets signed-in
      // users reach this screen — but guards against a stale session.
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in to add a bus.')));
      return;
    }

    await _dbService.insertBus(userId, _routeInfo!.label);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bus')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Autocomplete wraps a built-in text field and shows a
            // suggestion dropdown as the user types — no extra package
            // needed, this comes with Flutter's material library.
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue value) {
                if (value.text.isEmpty) return const Iterable<String>.empty();
                // Substring match, case-insensitive — e.g. typing "3"
                // matches any bus number containing "3", not just ones
                // starting with it.
                return _allBusNumbers.where(
                    (number) => number.toLowerCase().contains(value.text.toLowerCase()));
              },
              onSelected: (selection) {
                _busNumberController?.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Capture Autocomplete's own controller once so
                // _lookupBus() can read it directly — no separate mirror
                // controller or listener needed.
                _busNumberController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Enter Bus Number',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _lookupBus(),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_routeInfo != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _addToBusList,
                child: const Text('Add to Bus List',
                    style: TextStyle(color: Colors.white)),
              )
            else
              ElevatedButton(
                onPressed: _isLoading ? null : _lookupBus,
                child: _isLoading
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator())
                    : const Text('Look up Bus'),
              ),
            const SizedBox(height: 16),
            if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.red)),
            if (_routeInfo != null) ...[
              Text('${_routeInfo!.label} bus Info :',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Stops: ${_routeInfo!.stops}'),
              Text('Trip Duration: ${_routeInfo!.tripDurationMinutes} min'),
              const SizedBox(height: 12),
              const Text('Bus Route :', style: TextStyle(fontWeight: FontWeight.bold)),
              // TODO: Render the actual route shape (shapes.txt from GTFS)
              // on a small flutter_map preview once the real API is wired in.
              Container(
                height: 160,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text('Route map preview'),
              ),
              const SizedBox(height: 12),
              const Text('Bus Stops :', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: _routeInfo!.stopNames.length,
                  itemBuilder: (context, i) => Text('• ${_routeInfo!.stopNames[i]}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
