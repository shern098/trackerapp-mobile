import 'package:flutter/material.dart';
import '../models/train_model.dart';
import '../services/database_service.dart';
import '../services/transit_api_service.dart';
import '../main.dart' show currentUserNotifier;
import 'add_train_screen.dart';
import 'login_screen.dart';

class TrainListScreen extends StatefulWidget {
  const TrainListScreen({super.key});

  @override
  State<TrainListScreen> createState() => _TrainListScreenState();
}

class _TrainListScreenState extends State<TrainListScreen> {
  final _dbService = DatabaseService();
  final _apiService = TransitApiService();

  List<TrainModel> _savedTrains = [];
  bool _isLoadingSaved = true;

  List<String> _allTrainLines = [];
  bool _isLoadingAll = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshSavedTrains();
    _loadAllTrainLines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSavedTrains() async {
    final userId = currentUserNotifier.value?.id;
    final trains = userId != null ? await _dbService.getTrains(userId) : <TrainModel>[];
    if (mounted) setState(() { _savedTrains = trains; _isLoadingSaved = false; });
  }

  void _loadAllTrainLines() async {
    final lines = await _apiService.listTrainLines();
    if (mounted) setState(() { _allTrainLines = lines!; _isLoadingAll = false; });
  }

  bool _isSaved(String lineName) => _savedTrains.any((t) => t.lineName == lineName);

  void _quickAddTrain(String lineName) async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refreshSavedTrains();
      return;
    }
    await _dbService.insertTrain(currentUserNotifier.value!.id, lineName);
    _refreshSavedTrains();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added $lineName to My List')));
    }
  }

  void _deleteTrain(int id) async {
    await _dbService.deleteTrain(id);
    _refreshSavedTrains();
  }

  void _toggleRouteVisible(TrainModel train, bool value) async {
    await _dbService.updateTrain(train.copyWith(visible: value ? 1 : 0));
    _refreshSavedTrains();
  }

  void _onAddTrainPressed() async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refreshSavedTrains();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTrainScreen()));
    _refreshSavedTrains();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAll = _searchQuery.isEmpty
        ? _allTrainLines
        : _allTrainLines
            .where((n) => n.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Train List'),
          bottom: const TabBar(
            tabs: [Tab(text: 'All Trains'), Tab(text: 'My List')],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search train line',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Expanded(
                  child: _isLoadingAll
                      ? const Center(child: CircularProgressIndicator())
                      : filteredAll.isEmpty
                          ? const Center(child: Text('No matching train lines.'))
                          : ListView.builder(
                              itemCount: filteredAll.length,
                              itemBuilder: (context, index) {
                                final lineName = filteredAll[index];
                                final saved = _isSaved(lineName);
                                return ListTile(
                                  leading: const Icon(Icons.train),
                                  title: Text(lineName),
                                  trailing: saved
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () => _quickAddTrain(lineName),
                                        ),
                                );
                              },
                            ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: currentUserNotifier.value == null
                        ? const Center(
                            child: Text('Sign in to see and add your saved trains.',
                                textAlign: TextAlign.center),
                          )
                        : _isLoadingSaved
                            ? const Center(child: CircularProgressIndicator())
                            : _savedTrains.isEmpty
                                ? const Center(child: Text('No trains added yet.'))
                                : ListView.builder(
                                    itemCount: _savedTrains.length,
                                    itemBuilder: (context, index) {
                                      final train = _savedTrains[index];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: const BorderSide(color: Colors.black26)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.train, size: 36),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text('Train ${train.lineName}',
                                                        style:
                                                            const TextStyle(fontSize: 18)),
                                                  ),
                                                  IconButton(
                                                    icon: const CircleAvatar(
                                                      backgroundColor: Colors.red,
                                                      child:
                                                          Icon(Icons.close, color: Colors.white),
                                                    ),
                                                    onPressed: () => _deleteTrain(train.id),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('Toggle Route Visibility'),
                                                  Switch(
                                                    value: train.visible == 1,
                                                    onChanged: (v) =>
                                                        _toggleRouteVisible(train, v),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _onAddTrainPressed,
                      child: Text(currentUserNotifier.value == null
                          ? 'Sign In to Add Train'
                          : 'Add Train (detailed lookup)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
