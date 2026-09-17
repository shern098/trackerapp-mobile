class GtfsRoute {
  final String id;
  final String agencyId;
  final String shortName;
  final String longName;
  final int type;
  final String color;
  final String textColor;
  final String feedCategory;

  GtfsRoute({
    required this.id,
    required this.agencyId,
    required this.shortName,
    required this.longName,
    required this.type,
    required this.color,
    required this.textColor,
    this.feedCategory = '',
  });

  String get uniqueKey => '$feedCategory|$id';

  factory GtfsRoute.fromMap(Map<String, dynamic> map) {
    return GtfsRoute(
      id: map['route_id']?.toString() ?? '',
      agencyId: map['agency_id']?.toString() ?? '',
      shortName: map['route_short_name']?.toString() ?? '',
      longName: map['route_long_name']?.toString() ?? '',
      type: int.tryParse(map['route_type']?.toString() ?? '') ?? 0,
      color: map['route_color']?.toString() ?? '',
      textColor: map['route_text_color']?.toString() ?? '',
      feedCategory: map['feed_category']?.toString() ?? '',
    );
  }
}