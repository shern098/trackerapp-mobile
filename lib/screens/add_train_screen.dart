import 'package:flutter/material.dart';
import '../main.dart' show currentUserNotifier;
import '../services/database_service.dart';
import '../services/transit_api_service.dart';

/// Same shape as AddBusScreen, for train lines instead of bus numbers —
/// e.g. typing "kel" suggests "Kelana Jaya Line" before saving to the
/// "Trains" table. Only reachable while signed in.
class AddTrainScreen extends StatefulWidget {
  const AddTrainScreen({super.key});

  @override
  State<AddTrainScreen> createState() => _AddTrainScreenState();
}

class _AddTrainScreenState extends State<AddTrainScreen> {
  // Captured from Autocomplete's fieldViewBuilder below — this is
  // Autocomplete's own internally-managed controller, not one we create
  // ourselves, so we must NOT dispose it (Autocomplete disposes it
  // automatically; doing so ourselves too would crash).
  TextEditingController? _lineController;
  final _apiService = TransitApiService();
  final _dbService = DatabaseService();

  RouteInfo? _routeInfo;
  bool _isLoading = false;
  String? _errorText;
  List<String> _allTrainLines = []; // powers the Autocomplete suggestions below

  @override
  void initState() {
    super.initState();
    _loadTrainLineSuggestions();
  }

  void _loadTrainLineSuggestions() async {
    final lines = await _apiService.listTrainLines();
    if (mounted) setState(() => _allTrainLines = lines);
  }

  void _lookupTrain() async {
    final input = _lineController?.text.trim() ?? '';
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

    final userId = currentUserNotifier.value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in to add a train.')));
      return;
    }

    await _dbService.insertTrain(userId, _routeInfo!.label);
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
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue value) {
                if (value.text.isEmpty) return const Iterable<String>.empty();
                // Substring match, case-insensitive — this is what makes
                // typing "kel" suggest "Kelana Jaya Line".
                return _allTrainLines.where(
                    (line) => line.toLowerCase().contains(value.text.toLowerCase()));
              },
              onSelected: (selection) {
                _lineController?.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Capture Autocomplete's own controller once so
                // _lookupTrain() can read it directly — no separate mirror
                // controller or listener needed.
                _lineController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Enter Train Line',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _lookupTrain(),
                );
              },
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
