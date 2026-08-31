/// Represents one row from the "Buses" SQLite table — a bus route the
/// user has saved to track. Mirrors the fromJson/toMap pattern taught in
/// Practical 9 (SQLite): fromJson() reads a raw database row into a typed
/// object, toMap() does the reverse for writing back to the database.
class BusModel {
  final int id; // primary key, auto-assigned by SQLite
  final String busNumber; // e.g. "300" — the number the user typed in Add Bus
  final int iconVisible; // stored as 0/1 since SQLite has no boolean column type
  final int routeVisible; // same as above, for the "Toggle Route Visibility" switch

  BusModel({
    required this.id,
    required this.busNumber,
    required this.iconVisible,
    required this.routeVisible,
  });

  // Builds a BusModel from a raw database row (a Map<String, dynamic>).
  factory BusModel.fromJson(Map<String, dynamic> data) => BusModel(
        id: data['id'],
        busNumber: data['busNumber'],
        iconVisible: data['iconVisible'],
        routeVisible: data['routeVisible'],
      );

  // Converts this object back into a Map suitable for db.update()/db.insert().
  Map<String, dynamic> toMap() => {
        'id': id,
        'busNumber': busNumber,
        'iconVisible': iconVisible,
        'routeVisible': routeVisible,
      };

  // Returns a copy of this bus with one or more fields replaced — used by
  // the Toggle Icon/Route Visibility switches in bus_list_screen.dart,
  // since BusModel's fields are all `final` (immutable) by design.
  BusModel copyWith({int? iconVisible, int? routeVisible}) => BusModel(
        id: id,
        busNumber: busNumber,
        iconVisible: iconVisible ?? this.iconVisible,
        routeVisible: routeVisible ?? this.routeVisible,
      );
}
