class GtfsRoute {
  final String id;
  final String agencyId;
  final String shortName;
  final String longName;
  final int type;
  final String color;
  final String textColor;

  GtfsRoute({
    required this.id,
    required this.agencyId,
    required this.shortName,
    required this.longName,
    required this.type,
    required this.color,
    required this.textColor,
  });
}