import 'package:flutter/material.dart';
import '../models/train_model.dart';
import '../services/database_service.dart';
import '../main.dart' show currentUserNotifier;
import 'add_train_screen.dart';
import 'login_screen.dart';

/// Shows the signed-in user's saved train lines, with a delete (X)
/// button per entry instead of Bus List's toggle switches — matches the
/// original wireframe's Train List design. Same sign-in gating as
/// BusListScreen, since saved trains are per-account data too.
class TrainListScreen extends StatefulWidget {
  const TrainListScreen({super.key});

  @override
  State<TrainListScreen> createState() => _TrainListScreenState();
}

class _TrainListScreenState extends State<TrainListScreen> {
  final dbService = DatabaseService();
  Future<List<TrainModel>>? _trainsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final userId = currentUserNotifier.value?.id;
    setState(() {
      _trainsFuture = userId != null ? dbService.getTrains(userId) : null;
    });
  }

  void _deleteTrain(int id) async {
    await dbService.deleteTrain(id);
    _refresh();
  }

  void _onAddTrainPressed() async {
    if (currentUserNotifier.value == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      _refresh();
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTrainScreen()));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = currentUserNotifier.value == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Train List')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: isGuest
                  ? const Center(
                      child: Text('Sign in to see and add your saved trains.',
                          textAlign: TextAlign.center),
                    )
                  : FutureBuilder<List<TrainModel>>(
                      future: _trainsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No trains added yet.'));
                        }
                        final trains = snapshot.data!;
                        return ListView.builder(
                          itemCount: trains.length,
                          itemBuilder: (context, index) {
                            final train = trains[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.black26)),
                              child: ListTile(
                                leading: const Icon(Icons.train),
                                title: Text('Train ${train.lineName}',
                                    style: const TextStyle(fontSize: 18)),
                                trailing: IconButton(
                                  icon: const CircleAvatar(
                                    backgroundColor: Colors.red,
                                    child: Icon(Icons.close, color: Colors.white),
                                  ),
                                  onPressed: () => _deleteTrain(train.id),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _onAddTrainPressed,
                child: Text(isGuest ? 'Sign In to Add Train' : 'Add Train'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
