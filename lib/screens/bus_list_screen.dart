import 'package:flutter/material.dart';
import '../main.dart' show currentUserNotifier;
import '../models/bus_model.dart';
import '../services/database_service.dart';
import '../services/transit_api_service.dart';
import 'login_screen.dart';
import 'add_bus_screen.dart';



class BusListScreen extends StatefulWidget {
  const BusListScreen({super.key});

  @override
  State<BusListScreen> createState() => _BusListScreenState();
}

class _BusListScreenState extends State<BusListScreen> {
  final _dbService = DatabaseService();
  final _apiService = TransitApiService();

  List<BusModel> _savedBuses = [];
  bool _isLoadingSaved = true;
  List<String> _allBusNumbers = [];
  bool _isLoadingAll = true;
  String _searchQuery = '';

  final _searchController = TextEditingController();

  static const _busCategories = [
    'rapid-bus-kl',
    'rapid-bus-penang',
    'rapid-bus-kuantan',
    'rapid-bus-mrtfeeder',
  ];

  @override
  void initState() {
    super.initState();
    _refreshSavedBuses();
    _loadAllBusNumbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshSavedBuses() async {
    final userId = currentUserNotifier.value?.id;
    final buses = userId != null ? await _dbService.getBuses(userId) : <BusModel>[];
    if (mounted) setState(() { _savedBuses = buses; _isLoadingSaved = false; });
  }


  void _loadAllBusNumbers() async {
    final results = await Future.wait(
      _busCategories.map((cat) async {
        final numbers = await _apiService.listBusNumbers(category: cat);
        return numbers ?? <String>[];
      }),
    );

    final merged = results.expand((x) => x).toSet().toList()..sort();

    if (mounted) {
      setState(() {
        _allBusNumbers = merged;
        _isLoadingAll = false;
      });
    }
  }

  bool _isSaved(String busNumber) => _savedBuses.any((b) => b.busNumber == busNumber);

  void _quickAddBus(String busNumber) async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refreshSavedBuses();
      return;
    }
    await _dbService.insertBus(context, currentUserNotifier.value!.id, busNumber);
    _refreshSavedBuses();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Added bus $busNumber to My List')));
    }
  }

  void _toggleIconVisible(BusModel bus, bool value) async {
    await _dbService.updateBus(bus.copyWith(iconVisible: value ? 1 : 0));
    _refreshSavedBuses();
  }

  void _toggleRouteVisible(BusModel bus, bool value) async {
    await _dbService.updateBus(bus.copyWith(routeVisible: value ? 1 : 0));
    _refreshSavedBuses();
  }

  void _onAddBusPressed() async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refreshSavedBuses();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBusScreen()));
    _refreshSavedBuses();
  }

  void _deleteBus(BusModel bus) async {
    await _dbService.deleteBus(bus.id);
    _refreshSavedBuses();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed bus ${bus.busNumber} from list')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAll = _searchQuery.isEmpty
        ? _allBusNumbers
        : _allBusNumbers
        .where((n) => n.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bus List'),
          bottom: const TabBar(
            tabs: [Tab(text: 'All Buses'), Tab(text: 'My List')],
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
                      hintText: 'Search bus number',
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
                      ? const Center(child: Text('No matching bus routes.'))
                      : ListView.builder(
                    itemCount: filteredAll.length,
                    itemBuilder: (context, index) {
                      final number = filteredAll[index];
                      final saved = _isSaved(number);
                      return ListTile(
                        leading: const Icon(Icons.directions_bus),
                        title: Text('Bus $number'),
                        trailing: saved
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _quickAddBus(number),
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
                      child: Text('Sign in to see and add your saved buses.',
                          textAlign: TextAlign.center),
                    )
                        : _isLoadingSaved
                        ? const Center(child: CircularProgressIndicator())
                        : _savedBuses.isEmpty
                        ? const Center(child: Text('No buses added yet.'))
                        : ListView.builder(
                      itemCount: _savedBuses.length,
                      itemBuilder: (context, index) {
                        final bus = _savedBuses[index];
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
                                    const Icon(Icons.directions_bus, size: 36),
                                    const SizedBox(width: 12),
                                    Text('Bus No : ${bus.busNumber}',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Toggle Icon Visibility'),
                                    Switch(
                                      value: bus.iconVisible == 1,
                                      onChanged: (v) =>
                                          _toggleIconVisible(bus, v),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Toggle Route Visibility'),
                                    Switch(
                                      value: bus.routeVisible == 1,
                                      onChanged: (v) =>
                                          _toggleRouteVisible(bus, v),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Remove from list'),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteBus(bus),
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
                      onPressed: _onAddBusPressed,
                      child: Text(currentUserNotifier.value == null
                          ? 'Sign In to Add Bus'
                          : 'Add Bus (detailed lookup)'),
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
