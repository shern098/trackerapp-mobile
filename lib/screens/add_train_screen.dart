import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/transit_api_service.dart';

class AddTrainScreen extends StatefulWidget {
  const AddTrainScreen({super.key});

  @override
  State<AddTrainScreen> createState() => _AddTrainScreenState();
}

class _AddTrainScreenState extends State<AddTrainScreen> {
  final _lineController = TextEditingController();
  final _apiService = TransitApiService();
  final _dbService = DatabaseService();

  RouteInfo? _routeInfo;
  bool _isLoading = false;
  String? _errorText;

  void _lookupTrain() async {
    final input = _lineController.text.trim();
    if (input.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
      _routeInfo = null;
    });

    try {
      final info = await _apiService.fetchTrainInfo(input);
      setState(() {
        _routeInfo = info;
        _isLoading = false;
        if (info == null) _errorText = 'No line found for "$input".';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorText = 'Error: $e';
      });
    }
  }

  void _addToTrainList() async {
    if (_routeInfo == null) return;
    await _dbService.insertTrain(_routeInfo!.label);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Train')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _lineController,
              decoration: const InputDecoration(
                hintText: 'Enter Train Line',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _lookupTrain(),
            ),
            const SizedBox(height: 12),
            if (_routeInfo != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _addToTrainList,
                child: const Text('Add to Train List',
                    style: TextStyle(color: Colors.white)),
              )
            else
              ElevatedButton(
                onPressed: _isLoading ? null : _lookupTrain,
                child: _isLoading
                    ? const SizedBox(
                        height: 16, width: 16, child: CircularProgressIndicator())
                    : const Text('Look up Line'),
              ),
            const SizedBox(height: 16),
            if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.red)),
            if (_routeInfo != null) ...[
              Text('${_routeInfo!.label} Line Info :',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Stops: ${_routeInfo!.stops}'),
              Text('Trip Duration: ${_routeInfo!.tripDurationMinutes} min'),
              const SizedBox(height: 12),
              const Text('Train Route :', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                height: 160,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text('Route map preview'),
              ),
              const SizedBox(height: 12),
              const Text('Train Stations :', style: TextStyle(fontWeight: FontWeight.bold)),
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
