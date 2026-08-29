class BusModel {
  final int id;
  final String busNumber;
  final int iconVisible; // stored as 0/1 in SQLite (no bool column type)
  final int routeVisible;

  BusModel({
    required this.id,
    required this.busNumber,
    required this.iconVisible,
    required this.routeVisible,
  });

  factory BusModel.fromJson(Map<String, dynamic> data) => BusModel(
        id: data['id'],
        busNumber: data['busNumber'],
        iconVisible: data['iconVisible'],
        routeVisible: data['routeVisible'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'busNumber': busNumber,
        'iconVisible': iconVisible,
        'routeVisible': routeVisible,
      };

  BusModel copyWith({int? iconVisible, int? routeVisible}) => BusModel(
        id: id,
        busNumber: busNumber,
        iconVisible: iconVisible ?? this.iconVisible,
        routeVisible: routeVisible ?? this.routeVisible,
      );
}
