class OfficeLocation {
  const OfficeLocation({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });

  factory OfficeLocation.fromFirestore(String id, Map<String, dynamic> data) {
    final name = _text(data['name']);
    if (name == null) {
      throw const FormatException('Office name is required.');
    }
    return OfficeLocation(
      id: id,
      name: name,
      latitude: _coordinate(data['latitude'], 90),
      longitude: _coordinate(data['longitude'], 180),
    );
  }

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates =>
      _coordinate(latitude, 90) != null && _coordinate(longitude, 180) != null;

  static String? _text(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static double? _coordinate(Object? value, double limit) {
    if (value is! num || !value.isFinite || value.abs() > limit) return null;
    return value.toDouble();
  }
}
