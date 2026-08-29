import 'package:flutter/material.dart';
import '../models/train_model.dart';
import '../services/database_service.dart';
import 'add_train_screen.dart';

class TrainListScreen extends StatefulWidget {
  const TrainListScreen({super.key});

  @override
  State<TrainListScreen> createState() => _TrainListScreenState();
}

class _TrainListScreenState extends State<TrainListScreen> {
  final dbService = DatabaseService();
  late Future<List<TrainModel>> _trainsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _trainsFuture = dbService.getTrains();
    });
  }

  void _deleteTrain(int id) async {
    await dbService.deleteTrain(id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Train List')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: FutureBuilder<List<TrainModel>>(
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
                onPressed: () async {
                  await Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AddTrainScreen()));
                  _refresh();
                },
                child: const Text('Add Train'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
