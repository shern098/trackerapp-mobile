class TrainModel {
  final int id;
  final String lineName;
  final int visible; // 0/1

  TrainModel({
    required this.id,
    required this.lineName,
    required this.visible,
  });

  factory TrainModel.fromJson(Map<String, dynamic> data) => TrainModel(
        id: data['id'],
        lineName: data['lineName'],
        visible: data['visible'],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'lineName': lineName,
        'visible': visible,
      };

  TrainModel copyWith({int? visible}) => TrainModel(
        id: id,
        lineName: lineName,
        visible: visible ?? this.visible,
      );
}
