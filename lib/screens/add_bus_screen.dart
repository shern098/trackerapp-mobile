import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/transit_api_service.dart';

class AddBusScreen extends StatefulWidget {
  const AddBusScreen({super.key});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  final _busNumberController = TextEditingController();
  final _apiService = TransitApiService();
  final _dbService = DatabaseService();

  RouteInfo? _routeInfo;
  bool _isLoading = false;
  String? _errorText;

  void _lookupBus() async {
    final input = _busNumberController.text.trim();
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

  void _addToBusList() async {
    if (_routeInfo == null) return;
    await _dbService.insertBus(_routeInfo!.label);
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
            TextField(
              controller: _busNumberController,
              decoration: const InputDecoration(
                hintText: 'Enter Bus Number',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _lookupBus(),
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
