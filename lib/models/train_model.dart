/// Represents one row from the "Trains" SQLite table — a train line the
/// user has saved to track (e.g. "Kelana Jaya"). Same fromJson/toMap
/// pattern as BusModel and Practical 9's SQLite example.
class TrainModel {
  final int id; // primary key, auto-assigned by SQLite
  final String lineName; // e.g. "Kelana Jaya"
  final int visible; // 0/1 — whether this train's icon shows on the map

  TrainModel({
    required this.id,
    required this.lineName,
    required this.visible,
  });

  // Builds a TrainModel from a raw database row.
  factory TrainModel.fromJson(Map<String, dynamic> data) => TrainModel(
        id: data['id'],
        lineName: data['lineName'],
        visible: data['visible'],
      );

  // Converts this object back into a Map for db.update()/db.insert().
  Map<String, dynamic> toMap() => {
        'id': id,
        'lineName': lineName,
        'visible': visible,
      };

  // Returns a copy with `visible` replaced — used when the user toggles
  // train visibility (TrainModel's fields are immutable/`final`).
  TrainModel copyWith({int? visible}) => TrainModel(
        id: id,
        lineName: lineName,
        visible: visible ?? this.visible,
      );
}
